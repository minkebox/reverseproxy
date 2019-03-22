#! /bin/sh

if [ "${__HOME_INTERFACE}" != "" ]; then
  IFACE=${__HOME_INTERFACE}
elif [ "${__PRIVATE_INTERFACE}" != "" ]; then
  IFACE=${__PRIVATE_INTERFACE}
fi

IP=$(ip addr show dev ${IFACE} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)

touch /etc/dnshosts.d/hosts.conf
dnsmasq

# By default, if we cannot identify the correct server, we 404.
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
  firstsite=$(echo $globalsites | cut -d" " -f 1)
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
" > /etc/nginx/conf.d/${firstsite}.conf
    for gsite in ${globalsites}; do
      echo "${IP} ${gsite}" >> /etc/dnshosts.d/hosts.conf
      if [ "$(echo ${gsite} | grep '\.')" = "" ]; then
        echo "${IP} ${gsite}.${__DOMAINNAME}" >> /etc/dnshosts.d/hosts.conf
      fi
    done
  fi
done

for website in ${OTHER_WEBSITES}; do
  url=$(echo $website | cut -d"#" -f 1)
  globalsites=$(echo $website | cut -d"#" -f 2 | sed "s/,/ /g")
  firstsite=$(echo $globalsites | cut -d" " -f 1)
  echo "
server {
  server_name ${globalsites};
  listen *:${HTTP_PORT};
  location ~ {
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_pass ${url};
  }
}
" > /etc/nginx/conf.d/${firstsite}.conf
  for gsite in ${globalsites}; do
    echo "${IP} ${gsite}" >> /etc/dnshosts.d/hosts.conf
    if [ "$(echo ${gsite} | grep '\.')" = "" ]; then
      echo "${IP} ${gsite}.${__DOMAINNAME}" >> /etc/dnshosts.d/hosts.conf
    fi
  done
done

nginx

# Run until stopped
trap "nginx -s quit ; killall dnsmasq ; exit" TERM INT
sleep 2147483647d &
wait "$!"
