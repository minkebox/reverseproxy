#! /bin/sh

if [ "${__HOME_INTERFACE}" != "" ]; then
  IFACE=${__HOME_INTERFACE}
elif [ "${__PRIVATE_INTERFACE}" != "" ]; then
  IFACE=${__PRIVATE_INTERFACE}
fi

IP=$(ip addr show dev ${IFACE} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)

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
      fi
    done
  fi
done

nginx
dnsmasq

# Run until stopped
trap "nginx quit ; killall dnsmasq ; exit" TERM INT
sleep 2147483647d &
wait "$!"
