#!/bin/bash

get_ipv4 () {
  echo $1 | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"
}

cleanup() {
  if [ -x "./5050_check.sh" ]; then
    rm ./5050_check.sh
  fi
}

print_imports() {
cat << EOF > ./$1.json
{
	"Servers": {
		"1": {
			"Name": "$1",
			"Group": "Inside Environment",
			"Port": 5432,
			"Username": "postgres",
			"Host": "$1",
			"SSLMode": "prefer",
			"MaintenanceDB": "postgres"
		}
	}
}
EOF
}

pgadmin_scan() {
  if [ ! -x "./5050_check.sh" ]; then
    echo '#!/bin/bash' > ./5050_check.sh
    echo 'echo > /dev/tcp/$1/5050 && echo $1' >> ./5050_check.sh
    chmod +x ./5050_check.sh
  fi

  while read line; do
    first=`echo $line | awk '{print $1}'`
    ip=`get_ipv4 $first`

    if [ -z "$ip" -o "$ip" == "127.0.0.1" ]; then
      continue
    fi

    # fork in separate shell to redirect stderr
    out=$(./5050_check.sh $ip 2>/dev/null)

    if [ -z "$out" ]; then
      continue
    fi

    if [ "$out" == "$ip" ]; then
      echo "${line##* }"
      cleanup
      return 0
    fi
  done < /etc/hosts
  cleanup
  return 1
}

username="$1"

# Might not have a pgadmin server so this is a normal exit 
if [ -z "$username" ]; then
  echo Need a username to add this server to pgadmin
  exit 0 
fi

# Try to find a pgadmin server in the environment
pgadmin=`pgadmin_scan`
if [ -z "$pgadmin" ]; then
  echo no pgadmin found
  exit 0
fi

# If found generate import file, send, and import on pgadmin host
hostname=`hostname`
print_imports $hostname
cat ./$hostname.json
scp ./$hostname.json $pgadmin:/var/lib/pgadmin
ssh $pgadmin chown pgadmin:pgadmin /var/lib/pgadmin/$hostname.json
ssh $pgadmin sudo su - pgadmin setup_import.sh $username /var/lib/pgadmin/$hostname.json

exit 0
