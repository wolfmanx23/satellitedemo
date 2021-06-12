#!/usr/bin/env bash
cat << 'HERE' >>/usr/local/bin/ibm-host-attach.sh
#!/usr/bin/env bash
set -ex
mkdir -p /etc/satelliteflags
HOST_ASSIGN_FLAG="/etc/satelliteflags/hostattachflag"
if [[ -f "$HOST_ASSIGN_FLAG" ]]; then
	echo "host has already been assigned. need to reload before you try the attach again"
	exit 0
fi
set +x
HOST_QUEUE_TOKEN="6dfac1da09f93b32efac6a9ec8cd31642d658d5fa8fa0f4ddc9439f1a26971c4ecf597292578bafd75801f7504a5613ef5236f5bd71d68a46629035a1ce14671847a0836c9c3355acb6df6c14ca8d6cc896cacfee1c41baa445b66704774f2e455cf00a7622466f99615d9975cfa56f02c7815538e8c0e4fe74df4b8ee39e6ce5ff20012ec92d942b14435fcdcf04703051ebe4b068b95aa3ee6c55eda6999d4e7441f54e91f35acb1fa37cd60b662e25dc1682b796b863298b7298f2be739ee00d7471d9380efbdd9741db0d0dd8d4cea65737b2c507a016c6e6355b7970487e23c3bed507b74e9f042e8a773bd9d68f3721494097be988b580c3b0b3aed8a8"
set -x
ACCOUNT_ID="c529a69d5233fbc0bc7c1ae950677e88"
CONTROLLER_ID="c32bm51w0ebhl0uf0tig"
SELECTOR_LABELS='{"satellite":"demo"}'
API_URL="https://origin.us-east.containers.cloud.ibm.com/"

#shutdown known blacklisted services for Satellite (these will break kube)
set +e
systemctl stop -f iptables.service
systemctl disable iptables.service
systemctl mask iptables.service
systemctl stop -f firewalld.service
systemctl disable firewalld.service
systemctl mask firewalld.service
set -e

# ensure you can successfully communicate with redhat mirrors (this is a prereq to the rest of the automation working)
yum install rh-python36 -y
mkdir -p /etc/satellitemachineidgeneration
if [[ ! -f /etc/satellitemachineidgeneration/machineidgenerated ]]; then
	rm -f /etc/machine-id
	systemd-machine-id-setup
	touch /etc/satellitemachineidgeneration/machineidgenerated
fi
#STEP 1: GATHER INFORMATION THAT WILL BE USED TO REGISTER THE HOST
HOSTNAME=$(hostname -s)
HOSTNAME=${HOSTNAME,,}
MACHINE_ID=$(cat /etc/machine-id)
CPUS=$(nproc)
MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}')
export CPUS
export MEMORY
SELECTOR_LABELS=$(echo "${SELECTOR_LABELS}" | python -c "import sys, json, os; z = json.load(sys.stdin); y = {\"cpu\": os.getenv('CPUS'), \"memory\": os.getenv('MEMORY')}; z.update(y); print(json.dumps(z))")

set +e
export ZONE=""
echo "Probing for AWS metadata"
gather_zone_info() {
	HTTP_RESPONSE=$(curl --write-out "HTTPSTATUS:%{http_code}" --max-time 10 http://169.254.169.254/latest/meta-data/placement/availability-zone)
	HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')
	HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -E 's/HTTPSTATUS\:[0-9]{3}$//')
	if [[ "$HTTP_STATUS" -ne 200 ]]; then
		echo "bad return code"
		return 1
	fi
	if [[ "$HTTP_BODY" =~ [^a-zA-Z0-9-] ]]; then
		echo "invalid zone format"
		return 1
	fi
	ZONE="$HTTP_BODY"
}
if gather_zone_info; then
	echo "aws metadata detected"
fi
if [[ -z "$ZONE" ]]; then
	echo "echo Probing for Azure Metadata"
	export AZURE_ZONE_NUMBER_INFO=""
	gather_azure_zone_number_info() {
		HTTP_RESPONSE=$(curl -H Metadata:true --noproxy "*" --write-out "HTTPSTATUS:%{http_code}" --max-time 10 "http://169.254.169.254/metadata/instance/compute/zone?api-version=2021-01-01&format=text")
		HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')
		HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -E 's/HTTPSTATUS\:[0-9]{3}$//')
		if [[ "$HTTP_STATUS" -ne 200 ]]; then
			echo "bad return code"
			return 1
		fi
		if [[ "$HTTP_BODY" =~ [^a-zA-Z0-9-] ]]; then
			echo "invalid format"
			return 1
		fi
		AZURE_ZONE_NUMBER_INFO="$HTTP_BODY"
	}
	gather_zone_info() {
		if ! gather_azure_zone_number_info; then
			return 1
		fi
		ZONE="${AZURE_ZONE_NUMBER_INFO}"
	}
	if gather_zone_info; then
		echo "azure metadata detected"
	fi
fi
if [[ -z "$ZONE" ]]; then
	echo "echo Probing for GCE Metadata"
	gather_zone_info() {
		HTTP_RESPONSE=$(curl --write-out "HTTPSTATUS:%{http_code}" --max-time 10 "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google")
		HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')
		HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -E 's/HTTPSTATUS\:[0-9]{3}$//')
		if [[ "$HTTP_STATUS" -ne 200 ]]; then
			echo "bad return code"
			return 1
		fi
		POTENTIAL_ZONE_RESPONSE=$(echo "$HTTP_BODY" | awk -F '/' '{print $NF}')
		if [[ "$POTENTIAL_ZONE_RESPONSE" =~ [^a-zA-Z0-9-] ]]; then
			echo "invalid zone format"
			return 1
		fi
		ZONE="$POTENTIAL_ZONE_RESPONSE"
	}
	if gather_zone_info; then
		echo "gce metadata detected"
	fi
fi
set -e
if [[ -n "$ZONE" ]]; then
	SELECTOR_LABELS=$(echo "${SELECTOR_LABELS}" | python -c "import sys, json, os; z = json.load(sys.stdin); y = {\"zone\": os.getenv('ZONE')}; z.update(y); print(json.dumps(z))")
fi
#Step 2: SETUP METADATA
cat <<EOF >register.json
{
"controller": "$CONTROLLER_ID",
"name": "$HOSTNAME",
"identifier": "$MACHINE_ID",
"labels": $SELECTOR_LABELS
}
EOF

set +x
#STEP 3: REGISTER HOST TO THE HOSTQUEUE. NEED TO EVALUATE HTTP STATUS 409 EXISTS, 201 created. ALL OTHERS FAIL.
HTTP_RESPONSE=$(curl --write-out "HTTPSTATUS:%{http_code}" --retry 100 --retry-delay 10 --retry-max-time 1800 -X POST \
	-H "X-Auth-Hostqueue-APIKey: $HOST_QUEUE_TOKEN" \
	-H "X-Auth-Hostqueue-Account: $ACCOUNT_ID" \
	-H "Content-Type: application/json" \
	-d @register.json \
	"${API_URL}v2/multishift/hostqueue/host/register")
set -x
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -E 's/HTTPSTATUS\:[0-9]{3}$//')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')

echo "$HTTP_BODY"
echo "$HTTP_STATUS"
if [[ "$HTTP_STATUS" -ne 201 ]]; then
	echo "Error [HTTP status: $HTTP_STATUS]"
	exit 1
fi

HOST_ID=$(echo "$HTTP_BODY" | python -c "import sys, json; print(json.load(sys.stdin)['id'])")

#STEP 4: WAIT FOR MEMBERSHIP TO BE ASSIGNED
while true; do
	set +ex
	ASSIGNMENT=$(curl --retry 100 --retry-delay 10 --retry-max-time 1800 -G -X GET \
		-H "X-Auth-Hostqueue-APIKey: $HOST_QUEUE_TOKEN" \
		-H "X-Auth-Hostqueue-Account: $ACCOUNT_ID" \
		-d controllerID="$CONTROLLER_ID" \
		-d hostID="$HOST_ID" \
		"${API_URL}v2/multishift/hostqueue/host/getAssignment")
	set -ex
	isAssigned=$(echo "$ASSIGNMENT" | python -c "import sys, json; print(json.load(sys.stdin)['isAssigned'])" | awk '{print tolower($0)}')
	if [[ "$isAssigned" == "true" ]]; then
		break
	fi
	if [[ "$isAssigned" != "false" ]]; then
		echo "unexpected value for assign retrying"
	fi
	sleep 10
done

#STEP 5: ASSIGNMENT HAS BEEN MADE. SAVE SCRIPT AND RUN
echo "$ASSIGNMENT" | python -c "import sys, json; print(json.load(sys.stdin)['script'])" >/usr/local/bin/ibm-host-agent.sh
export HOST_ID
ASSIGNMENT_ID=$(echo "$ASSIGNMENT" | python -c "import sys, json; print(json.load(sys.stdin)['id'])")
cat <<EOF >/etc/satelliteflags/ibm-host-agent-vars
export HOST_ID=${HOST_ID}
export ASSIGNMENT_ID=${ASSIGNMENT_ID}
EOF
chmod 0600 /etc/satelliteflags/ibm-host-agent-vars
chmod 0700 /usr/local/bin/ibm-host-agent.sh
cat <<EOF >/etc/systemd/system/ibm-host-agent.service
[Unit]
Description=IBM Host Agent Service
After=network.target

[Service]
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/local/bin/ibm-host-agent.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 /etc/systemd/system/ibm-host-agent.service
systemctl daemon-reload
systemctl start ibm-host-agent.service
touch "$HOST_ASSIGN_FLAG"
HERE

chmod 0700 /usr/local/bin/ibm-host-attach.sh
cat << 'EOF' >/etc/systemd/system/ibm-host-attach.service
[Unit]
Description=IBM Host Attach Service
After=network.target

[Service]
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/local/bin/ibm-host-attach.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 /etc/systemd/system/ibm-host-attach.service
systemctl daemon-reload
systemctl enable ibm-host-attach.service
systemctl start ibm-host-attach.service
