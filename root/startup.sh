#! /bin/sh

if [ "${__HOME_INTERFACE}" != "" ]; then
  IFACE=${__HOME_INTERFACE}
elif [ "${__PRIVATE_INTERFACE}" != "" ]; then
  IFACE=${__PRIVATE_INTERFACE}
fi

IP=$(ip addr show dev ${IFACE} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)

mkdir -p /etc/dnshosts.d
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
      if [ "$(echo ${gsite} | grep '\.')" = "" ]; then
        echo "${IP} ${gsite}
${IP} ${gsite}.${__DOMAINNAME}" > /etc/dnshosts.d/${gsite}.conf
      else
        echo "${IP} ${gsite}" > /etc/dnshosts.d/${gsite}.conf
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
    if [ "$(echo ${gsite} | grep '\.')" = "" ]; then
      echo "${IP} ${gsite}
${IP} ${gsite}.${__DOMAINNAME}" > /etc/dnshosts.d/${gsite}.conf
    else
      echo "${IP} ${gsite}" > /etc/dnshosts.d/${gsite}.conf
    fi
  done
done

nginx
sleep 5
# If we failed to start, wait a while and retry. This can happen if the servers
# we're proxying have not started yet.
if [ "$(ps | grep nginx | grep master)" = "" ]; then
  sleep 60
  nginx
fi

# Run until stopped
trap "nginx -s quit ; killall dnsmasq ; exit" TERM INT
sleep 2147483647d &
wait "$!"
