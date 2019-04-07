#!/bin/bash

if ((UID!=0)); then
    echo >&2 "$0 need root privileges"
    exit 1
fi

for db in $(mysql -e "SHOW DATABASES" | awk 'NR>2 && !/performance_schema/'); do
    mysqldump --skip-lock-tables --events --quote-names --opt $db | gzip -9 - > ${db}_dump-$(date +%Y%m%d%H%M).sql.gz
done

mysql<<EOF
drop database amavisd;
drop database iredadmin;
drop database roundcubemail;
drop database sogo;
drop database vmail;
EOF
systemctl stop mysql
systemctl disable mysql
mv /var/vmail /var/vmail.$(date +%y%m%d)
cp -a /etc/nginx /etc/nginx-$(date +%y%m%d)
rm /etc/nginx/sites-enabled/*default*
rm /etc/nginx/templates/sogo.tmpl
rm /etc/nginx/templates/redirect_to_https.tmpl
apt-get purge sogo roundcube\* postfix\* apache\* php5\* postfix\* dovecot\* amavis\* clamav\* spamassassin\* awstats\* logwatch freshclam
sed -i 's@.*packages.inverse.ca/SOGo/nightly/.*@# &/' /etc/apt/sources.list
rm /etc/fail2ban/filter.d/roundcube.iredmail.conf
cd /root
rename "s/iRed.*/$&.$(date +%Y%m%d)/g" iRed*
cd /opt/
rename "s/iRed.*/$&.$(date +%Y%m%d)/g" iRed*
mv www www-$(date +%Y%m%d)
unlink iredapd
cd /root
wget $(curl -s https://bitbucket.org/zhb/iredmail/downloads/ | awk -F'[<>]' '/tar\.bz2/{print "https://bitbucket.org/zhb/iredmail/downloads/"$2;exit}')
tar xjvf iRedMail-0.9.9.tar.bz2
cd iRedMail-0.9.9
bash iRedMail.sh
cd /var/
rsync -avP vmail.*/ vmail/
rm -rf vmail.*
for db in amavisd iredadmin roundcubemail sogo vmail; do
    zcat ${db}_dump-*.sql.gz | mariadb $db
done 
