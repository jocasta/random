#!/bin/bash
FQDN=$1

if [[ $# -eq 0 ]] ; then
    echo 'You need to specify a Fully Qualified Domain Name'
    exit 0
fi

echo "Creating certificate for $FQDN"
IPADDR=$(dig +short $FQDN)
if [ -z "$IPADDR" ]; then
  echo "$FQDN does not resolve to an IP address!"
  echo "You must supply a fully qualified hostname that is registered in DNS"
  exit 1
fi

echo "$FQDN resolves to: $IPADDR"
HOSTNAME=${FQDN%%.*}
DOMAIN=${FQDN#*.}
BASE_DIR="/var/certs/$FQDN"

echo "Creating directory $BASE_DIR"
if [ -d $BASE_DIR ]; then
  echo "$BASE_DIR already exists!"
  echo "If you really want to recreate certs for $FQDN, please remove or rename it"
  exit 1
else
  mkdir -p $BASE_DIR
fi

CFG_FILE="$BASE_DIR/${FQDN}.cfg"
echo -e "\nCreating config file $CFG_FILE"
cat > $CFG_FILE << EOF
[req]
distinguished_name = $FQDN
req_extensions = v3_req
prompt = no

[$FQDN]
C = UK
ST = Edinburgh
L = Edinburgh
O = Registers of Scotland
CN = $FQDN

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $FQDN
DNS.2 = $HOSTNAME
IP.1 = $IPADDR
IP.2 = 127.0.0.1
EOF


KEY_FILE="$BASE_DIR/${FQDN}.key"
echo -e "\nGenerating private key $KEY_FILE"
openssl genrsa -out $KEY_FILE 2048

CSR_FILE="$BASE_DIR/${FQDN}.csr"
echo -e "\nGenerating CSR $CSR_FILE"
openssl req -new -out $CSR_FILE -key $KEY_FILE -config $CFG_FILE

echo "The CSR has been generated:"
cat $CSR_FILE

CA_FILE="$BASE_DIR/RoS-Local-RootCA.crt"
sed -n '/^# RoS-Local-RootCA/,/^-----END CERTIFICATE-----/p' /etc/pki/tls/certs/ca-bundle.crt | grep -v "RoS-Local-RootCA" > $CA_FILE
if [[ $? -ne 0 ]] ; then
    echo "Couldn't find RoS-Local-RootCA in /etc/pki/tls/certs/ca-bundle.crt - you will have to find it yourself!"
    exit 0
fi
printf "$CA_FILE\nRoS-Local-RootCA is:\n"
cat $CA_FILE
