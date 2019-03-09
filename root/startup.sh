#! /bin/sh

if [ "${__HOME_INTERFACE}" != "" ]; then
  IFACE=${__HOME_INTERFACE}
elif [ "${__PRIVATE_INTERFACE}" != "" ]; then
  IFACE=${__PRIVATE_INTERFACE}
fi

IP=$(ip addr show dev ${IFACE} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)

ddns_names=""
last_external_ip=""
function ddns() {
  sleep 1 &
  while wait "$!"; do
    external_ip=$(upnpc -m ${IFACE} -s | grep ExternalIPAddress | sed "s/^.*= //")
    if [ "${external_ip}" != "${last_external_ip}" ]; then
      last_external_ip=${external_ip}
      for name in $ddns_names; do
        url=$(echo $DDNS_URL | sed "s/{{IP}}/${IP}/g" | sed "s/{{HOSTNAME}}/@/g" | sed "s/{{DOMAINNAME}/${name}/g")
        wget --no-check-certificate -q -O - "${url}"
      done
    fi
    sleep 1800 &
  done
}

for website in ${WEBSITES}; do
  site=$(echo $website | cut -d"#" -f 1)
  port=$(echo $website | cut -d"#" -f 2)
  globalsites=$(echo $website | cut -d"#" -f 3 | sed "s/,/ /g")
  enabled=$(echo $website | cut -d"#" -f 4)
  if [ "${enabled}" = "true" -a "${globalsites}" != "" ]; then
    echo "
server {
  server_name ${globalsites};
  listen *:80;
  location ~ {
    proxy_bind ${IP};
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_pass http://${site}:${port};
  }
}
" > /etc/nginx/conf.d/${site}.conf
    for gsite in ${globalsites}; do
      echo "${IP} ${gsite}" >> /etc/dnshosts.d/hosts.conf
      if [ "$(echo ${gsite} | grep '\.')" = "" ]; then
        echo "${IP} ${gsite}.${__DOMAINNAME}" >> /etc/dnshosts.d/hosts.conf
      else
        ddns_names="${dds_names} ${gsite}"
      fi
    done
  fi
done

nginx
dnsmasq
if [ "${DDNS_URL}" != "" ]; then
  ddns &
fi

# Run until stopped
trap "nginx quit ; killall dnsmasq ; exit" TERM INT
sleep 2147483647d &
wait "$!"
