#! /bin/sh -x

if [ "${__HOME_INTERFACE}" != "" ]; then
  IFACE=${__HOME_INTERFACE}
elif [ "${__PRIVATE_INTERFACE}" != "" ]; then
  IFACE=${__PRIVATE_INTERFACE}
fi

IP=$(ip addr show dev ${IFACE} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)

touch /etc/dnshosts.d/hosts.conf
dnsmasq

ddns_names=""
last_external_ip=""
function ddns() {
  sleep 1 &
  while wait "$!"; do
    external_ip=$(upnpc -m ${IFACE} -s | grep ExternalIPAddress | sed "s/^.*= //")
    if [ "${external_ip}" != "${last_external_ip}" ]; then
      last_external_ip=${external_ip}
      for name in $ddns_names; do
        hostname=$(echo $name | cut -d'#' -f 1)
        domainname=$(echo $name | cut -d'#' -f 2-)
        url=$(echo $DDNS_URL | sed "s/{{IP}}/${IP}/g" | sed "s/{{HOSTNAME}}/${hostname}/g" | sed "s/{{DOMAINNAME}}/${domainname}/g")
        wget --no-check-certificate -S -O - "${url}"
      done
    fi
    sleep 1800 &
  done
}

# By default, if we cannot identify the correct server, we error.
echo "
server {
  server_name _;
  listen *:${HTTP_PORT} default_server;
  return 404;
}
" > /etc/nginx/conf.d/__default.conf

for website in ${WEBSITES}; do
  site=$(echo $website | cut -d"#" -f 1)
  port=$(echo $website | cut -d"#" -f 2)
  globalsites=$(echo $website | cut -d"#" -f 3 | sed "s/,/ /g")
  enabled=$(echo $website | cut -d"#" -f 4)
  if [ "${enabled}" = "true" -a "${globalsites}" != "" ]; then
    echo "
server {
  server_name ${globalsites};
  listen *:${HTTP_PORT};
  location ~ {
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
      elif [ "${DDNS_URL}" != "" ]; then
        hostname=$(echo ${gsite} | cut -d'.' -f 1)
        domainname=$(echo ${gsite} | cut -d'.' -f 2-)
        if [ "$(echo ${domainname} | grep '\.')" = "" ]; then
          ddns_names="${dds_names} #${hostname}.${domainname}"
        elif [ "$(whois ${domainname} | grep 'NOT FOUND')" != "" ]; then
          ddns_names="${dds_names} #${hostname}.${domainname}"
        else
          ddns_names="${dds_names} ${hostname}#${domainname}"
        fi
      fi
    done
  fi
done

nginx
if [ "${ddns_names}" != "" ]; then
  ddns &
fi

# Run until stopped
trap "nginx quit ; killall dnsmasq ; exit" TERM INT
sleep 2147483647d &
wait "$!"
