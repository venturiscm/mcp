#!/usr/bin/env bash
#-------------------------------------------------------------------------------
set -e

TOP_DIR="`pwd`"
APP_USER="${1:-vagrant}"
LOG_FILE="${2:-/dev/stderr}"
TIME_ZONE="${3:-America/New_York}"

if [ "$APP_USER" == 'root' ]
then
    APP_HOME="/root"
else
    APP_HOME="/home/${APP_USER}"
fi
#-------------------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

echo "Upgrading core OS packages" | tee -a "$LOG_FILE"
apt-get update -y >>"$LOG_FILE" 2>&1
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade >>"$LOG_FILE" 2>&1

echo "Installing core dependencies" | tee -a "$LOG_FILE"
apt-get install -y \
        apt-utils \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg2 \
        curl \
        wget \
     >>"$LOG_FILE" 2>&1

echo "Syncronizing time" | tee -a "$LOG_FILE"
apt-get --yes install ntpdate >>"$LOG_FILE" 2>&1
ntpdate 0.amazon.pool.ntp.org >>"$LOG_FILE" 2>&1

echo "Installing development tools" | tee -a "$LOG_FILE"
apt-get install -y \
        net-tools \
        git \
        g++ \
        gcc \
        make \
        python3-pip \
     >>"$LOG_FILE" 2>&1

pip3 install --no-cache-dir -r "${APP_HOME}/requirements-docs.txt" >>"$LOG_FILE" 2>&1

echo "Installing Docker" | tee -a "$LOG_FILE"
apt-key adv --fetch-keys https://download.docker.com/linux/ubuntu/gpg >>"$LOG_FILE" 2>&1
add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable" \
    >>"$LOG_FILE" 2>&1

sudo apt-get update >>"$LOG_FILE" 2>&1
apt-get install -y docker-ce >>"$LOG_FILE" 2>&1
usermod -aG docker "$APP_USER" >>"$LOG_FILE" 2>&1

echo "Installing Docker Compose" | tee -a "$LOG_FILE"
curl -L -o /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/1.25.1/docker-compose-Linux-x86_64 >>"$LOG_FILE" 2>&1
chmod 755 /usr/local/bin/docker-compose >>"$LOG_FILE" 2>&1

echo "Installing Redis CLI" | tee -a "$LOG_FILE"
mkdir -p /tmp/redis
cd /tmp/redis
wget http://download.redis.io/redis-stable.tar.gz
tar xvzf redis-stable.tar.gz >>"$LOG_FILE" 2>&1
cd redis-stable
make >>"$LOG_FILE" 2>&1
cp -f src/redis-cli /usr/local/bin/
chmod 755 /usr/local/bin/redis-cli
cd "$TOP_DIR"
rm -Rf /tmp/redis

echo "Ensuring certificates" | tee -a "$LOG_FILE"
if [ ! "$(ls -A ${APP_HOME}/certs)" ];
then
    "${APP_HOME}/bin/create-certs" "${APP_HOME}/certs" >>"$LOG_FILE" 2>&1
fi
cat > /etc/profile.d/mcmi-certs.sh <<END
export MCMI_CA_KEY="$(cat "${APP_HOME}/certs/mcmi-ca.key")"
export MCMI_CA_CERT="$(cat "${APP_HOME}/certs/mcmi-ca.crt")"
export MCMI_KEY="$(cat "${APP_HOME}/certs/mcmi.key")"
export MCMI_CERT="$(cat "${APP_HOME}/certs/mcmi.crt")"
END
source /etc/profile.d/mcmi-certs.sh

echo "Initializing configuration" | tee -a "$LOG_FILE"
if [ ! -f /var/local/mcmi/.env ]
then
    cat > /var/local/mcmi/.env <<END
MCMI_TIME_ZONE=$TIME_ZONE
MCMI_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1)
MCMI_POSTGRES_DB=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
MCMI_POSTGRES_USER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
MCMI_POSTGRES_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
MCMI_REDIS_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
END
    env | grep "MCMI_" >> /var/local/mcmi/.env
fi
ln -fs /var/local/mcmi/.env "${APP_HOME}/.env"

echo "Building application" | tee -a "$LOG_FILE"
docker-compose -f "${APP_HOME}/docker-compose.yml" build >>"$LOG_FILE" 2>&1

echo "Running application server" | tee -a "$LOG_FILE"
docker-compose -f "${APP_HOME}/docker-compose.yml" up -d >>"$LOG_FILE" 2>&1
