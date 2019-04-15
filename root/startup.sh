#! /bin/sh

if [ "${__HOME_INTERFACE}" != "" ]; then
  IFACE=${__HOME_INTERFACE}
elif [ "${__PRIVATE_INTERFACE}" != "" ]; then
  IFACE=${__PRIVATE_INTERFACE}
fi

IP=$(ip addr show dev ${IFACE} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1)

mkdir -p /etc/dnshosts.d
dnsmasq

# Setup acme.sh
. /etc/acme.sh/acme.sh.env

# By default, if we cannot identify the correct server, we 404.
if [ "${LETS_ENCRYPT}" = "false" ]; then
  echo "
server {
  server_name _;
  listen *:80 default_server;
  return 404;
}
" > /etc/nginx/conf.d/__default.conf
else
  echo "
server {
  server_name _;
  listen *:80 default_server;
  listen *:443 ssl http2 default_server;
  ssl_certificate /etc/nginx/dummykeys/dummy.crt;
  ssl_certificate_key /etc/nginx/dummykeys/dummy.key;
  return 404;
}
" > /etc/nginx/conf.d/__default.conf
fi

for website in ${WEBSITES}; do
  site=$(echo $website | cut -d"#" -f 1)
  port=$(echo $website | cut -d"#" -f 2)
  globalsites=$(echo $website | cut -d"#" -f 3 | sed "s/,/ /g")
  firstsite=$(echo $globalsites | cut -d" " -f 1)
  enabled=$(echo $website | cut -d"#" -f 4)
  if [ "${enabled}" = "true" -a "${globalsites}" != "" ]; then
    if [ "${LETS_ENCRYPT}" = "false" ]; then
      echo "
server {
  server_name ${globalsites};
  listen *:80;
  location ~ {
    client_max_body_size 100M;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass http://${site}:${port};
  }
  access_log /var/log/nginx/${firstsite}-access.log;
}
" > /etc/nginx/sites-enabled/${firstsite}.conf
    else
      echo "
server {
  server_name ${globalsites};
  listen *:80;
  location ^~ /.well-known/acme-challenge/ {
    alias /acme/.well-known/acme-challenge/;
  }
  location ~ {
    return 302 https://${firstsite}\$request_uri;
  }
  access_log /var/log/nginx/${firstsite}-access.log;
}
server {
  server_name ${globalsites};
  listen *:443 ssl http2;
  ssl on;
  ssl_certificate /etc/nginx/acme.sh/${firstsite}/fullcrt;
  ssl_certificate_key /etc/nginx/acme.sh/${firstsite}/key;
  ssl_trusted_certificate /etc/nginx/acme.sh/${firstsite}/crt;
  location ~ {
    client_max_body_size 100M;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass http://${site}:${port};
  }
  access_log /var/log/nginx/${firstsite}-access.log;
}
" > /etc/nginx/sites-enabled/${firstsite}.conf
      if [ ! -d /etc/nginx/acme.sh/${firstsite} ]; then
        # Use dummy certs so we can startup nginx and request real ones
        echo "Copy dummy certs into ${firstsite}"
        mkdir -p /etc/nginx/acme.sh/${firstsite}
        cp /etc/nginx/dummykeys/dummy.crt /etc/nginx/acme.sh/${firstsite}/crt
        cp /etc/nginx/dummykeys/dummy.crt /etc/nginx/acme.sh/${firstsite}/fullcrt
        cp /etc/nginx/dummykeys/dummy.key /etc/nginx/acme.sh/${firstsite}/key
      fi
    fi
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
  if [ "${LETS_ENCRYPT}" = "false" ]; then
    echo "
server {
  server_name ${globalsites};
  listen *:80;
  location ~ {
    client_max_body_size 100M;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass ${url};
  }
  access_log /var/log/nginx/${firstsite}-access.log;
}
" > /etc/nginx/sites-enabled/${firstsite}.conf
  else
    echo "
server {
  server_name ${globalsites};
  listen *:80;
  location ^~ /.well-known/acme-challenge/ {
    alias /acme/.well-known/acme-challenge/;
  }
  location ~ {
    return 302 https://${firstsite}\$request_uri;
  }
  access_log /var/log/nginx/${firstsite}-access.log;
}
server {
  server_name ${globalsites};
  listen *:443 ssl http2;
  ssl on;
  ssl_certificate /etc/nginx/acme.sh/${firstsite}/fullcrt;
  ssl_certificate_key /etc/nginx/acme.sh/${firstsite}/key;
  ssl_trusted_certificate /etc/nginx/acme.sh/${firstsite}/crt;
  location ~ {
    client_max_body_size 100M;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass ${url};
  }
  access_log /var/log/nginx/${firstsite}-access.log;
}
" > /etc/nginx/sites-enabled/${firstsite}.conf
  fi
  for gsite in ${globalsites}; do
    if [ "$(echo ${gsite} | grep '\.')" = "" ]; then
      echo "${IP} ${gsite}
${IP} ${gsite}.${__DOMAINNAME}" > /etc/dnshosts.d/${gsite}.conf
    else
      echo "${IP} ${gsite}" > /etc/dnshosts.d/${gsite}.conf
    fi
  done
done

for website in ${REDIRECT_WEBSITES}; do
  url=$(echo $website | cut -d"#" -f 1)
  globalsites=$(echo $website | cut -d"#" -f 2 | sed "s/,/ /g")
  firstsite=$(echo $globalsites | cut -d" " -f 1)
  if [ "${LETS_ENCRYPT}" = "false" ]; then
    echo "
server {
  server_name ${globalsites};
  listen *:80;
  location ~ {
    return 302 ${url}\$request_uri;
  }
  access_log /var/log/nginx/${firstsite}-access.log;
}
" > /etc/nginx/sites-enabled/${firstsite}.conf
  else
    echo "
server {
  server_name ${globalsites};
  listen *:80;
  location ^~ /.well-known/acme-challenge/ {
    alias /acme/.well-known/acme-challenge/;
  }
  location ~ {
    return 302 ${url}\$request_uri;
  }
  access_log /var/log/nginx/${firstsite}-access.log;
}
server {
  server_name ${globalsites};
  listen *:443 ssl http2;
  ssl on;
  ssl_certificate /etc/nginx/acme.sh/${firstsite}/fullcrt;
  ssl_certificate_key /etc/nginx/acme.sh/${firstsite}/key;
  ssl_trusted_certificate /etc/nginx/acme.sh/${firstsite}/crt;
  location ~ {
    return 302 ${url}\$request_uri;
  }
  access_log /var/log/nginx/${firstsite}-access.log;
}
" > /etc/nginx/sites-enabled/${firstsite}.conf
    if [ ! -d /etc/nginx/acme.sh/${firstsite} ]; then
      # Use dummy certs so we can startup nginx and request real ones
      echo "Copy dummy certs into ${firstsite}"
      mkdir -p /etc/nginx/acme.sh/${firstsite}
      cp /etc/nginx/dummykeys/dummy.crt /etc/nginx/acme.sh/${firstsite}/crt
      cp /etc/nginx/dummykeys/dummy.crt /etc/nginx/acme.sh/${firstsite}/fullcrt
      cp /etc/nginx/dummykeys/dummy.key /etc/nginx/acme.sh/${firstsite}/key
    fi
  fi
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

if [ "${LETS_ENCRYPT}" = "true" ]; then
  # Request any certs we don't already have
  mkdir -p /acme
  chmod 755 /acme
  for website in ${WEBSITES}; do
    globalsites=$(echo $website | cut -d"#" -f 3 | sed "s/,/ /g")
    firstsite=$(echo $globalsites | cut -d" " -f 1)
    enabled=$(echo $website | cut -d"#" -f 4)
    if [ "${enabled}" = "true" ]; then
      # Request keys if we're currently using the dummy key
      if cmp -s /etc/nginx/acme.sh/${firstsite}/key /etc/nginx/dummykeys/dummy.key; then
        acme.sh --issue --force -d $(echo ${globalsites} | sed "s/ / -d /g") -w /acme
        if [ -e /etc/acme.sh/data/${firstsite}/${firstsite}.cer ]; then
          acme.sh --install-cert -d ${firstsite} \
            --cert-file /etc/nginx/acme.sh/${firstsite}/crt \
            --key-file /etc/nginx/acme.sh/${firstsite}/key \
            --fullchain-file /etc/nginx/acme.sh/${firstsite}/fullcrt \
            --reloadcmd "nginx -s reload"
        else
          echo "Cert issue failure: ${firstsite}"
        fi
      fi
    fi
  done
  for website in ${OTHER_WEBSITES}; do
    globalsites=$(echo $website | cut -d"#" -f 2 | sed "s/,/ /g")
    firstsite=$(echo $globalsites | cut -d" " -f 1)
    # Request keys if we're currently using the dummy key
    if cmp -s /etc/nginx/acme.sh/${firstsite}/key /etc/nginx/dummykeys/dummy.key; then
      acme.sh --issue --force -d $(echo ${globalsites} | sed "s/ / -d /g") -w /acme
      if [ -e /etc/acme.sh/data/${firstsite}/${firstsite}.cer ]; then
        acme.sh --install-cert -d ${firstsite} \
          --cert-file /etc/nginx/acme.sh/${firstsite}/crt \
          --key-file /etc/nginx/acme.sh/${firstsite}/key \
          --fullchain-file /etc/nginx/acme.sh/${firstsite}/fullcrt \
          --reloadcmd "nginx -s reload"
      else
        echo "Cert issue failure: ${firstsite}"
      fi
    fi
  done
  for website in ${REDIRECT_WEBSITES}; do
    globalsites=$(echo $website | cut -d"#" -f 2 | sed "s/,/ /g")
    firstsite=$(echo $globalsites | cut -d" " -f 1)
    # Request keys if we're currently using the dummy key
    if cmp -s /etc/nginx/acme.sh/${firstsite}/key /etc/nginx/dummykeys/dummy.key; then
      acme.sh --issue --force -d $(echo ${globalsites} | sed "s/ / -d /g") -w /acme
      if [ -e /etc/acme.sh/data/${firstsite}/${firstsite}.cer ]; then
        acme.sh --install-cert -d ${firstsite} \
          --cert-file /etc/nginx/acme.sh/${firstsite}/crt \
          --key-file /etc/nginx/acme.sh/${firstsite}/key \
          --fullchain-file /etc/nginx/acme.sh/${firstsite}/fullcrt \
          --reloadcmd "nginx -s reload"
      else
        echo "Cert issue failure: ${firstsite}"
      fi
    fi
  done
  # Reload for updated certs
  nginx -s reload
  # Keep certs up-to-date
  crond
fi

# Run until stopped
trap "nginx -s quit ; killall dnsmasq crond; exit" TERM INT
sleep 2147483647d &
wait "$!"
