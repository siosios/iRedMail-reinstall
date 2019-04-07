#!/bin/bash

if ((UID!=0)); then
    echo >&2 "$0 need root privileges"
    exit 1
fi

set -eox pipefail

apt-get update -y
apt-get install -y wget curl
if [[ ! $(file $(readlink -f $(type -p rename))) == *Perl* ]]; then
    (
        cd /usr/local/bin
        wget 'https://metacpan.org/raw/RMBARKER/File-Rename-0.20/rename.PL?download=1'
        mv rename.PL rename
        chmod +x rename
    )
fi
bkpdir=/root/mysql_backup_reinstall_iRedMail
mkdir -p $bkpdir
for db in $(mysql -e "SHOW DATABASES" | awk 'NR>2 && !/performance_schema/'); do
    mysqldump --skip-lock-tables --events --quote-names --opt $db | gzip -9 - > $bkpdir/${db}_dump-$(date +%Y%m%d%H%M).sql.gz
done

if ! mysql -e '' &>/dev/null; then
    cat<<-EOF
	Please, create a /root/.my.cnf file with credentials, example : 

	[client]
	user=root
	password="foobarbase"
	EOF
fi

mysql<<EOF
DROP DATABASE amavisd;
DROP DATABASE iredadmin;
DROP DATABASE roundcubemail;
DROP DATABASE sogo;
DROP DATABASE vmail;
EOF
systemctl stop mysql
systemctl disable mysql
mv /var/vmail /var/vmail.$(date +%y%m%d)
cp -a /etc/nginx /etc/nginx-$(date +%y%m%d)
rm -f /etc/nginx/sites-enabled/*default* /etc/nginx/templates/sogo.tmpl /etc/nginx/templates/redirect_to_https.tmpl
apt-get purge sogo roundcube\* postfix\* apache\* php5\* postfix\* dovecot\* amavis\* clamav\* spamassassin\* awstats\* logwatch freshclam
sed -i 's@.*packages.inverse.ca/SOGo/nightly/.*@# &/' /etc/apt/sources.list
rm /etc/fail2ban/filter.d/roundcube.iredmail.conf
cd /root
/usr/local/bin/rename "s/iRed.*/$&.$(date +%Y%m%d)/g" iRed*
cd /opt/
/usr/local/bin/rename "s/iRed.*/$&.$(date +%Y%m%d)/g" iRed*
mv www www-$(date +%Y%m%d)
unlink iredapd
cd /root
wget $(
    curl -s https://bitbucket.org/zhb/iredmail/downloads/ |
    awk -F'[<>]' '/tar\.bz2/{print "https://bitbucket.org/zhb/iredmail/downloads/"$2;exit}'
)
tar xjvf iRedMail-*.tar.bz2
cd iRedMail-*
bash iRedMail.sh
cd /var/
rsync -avP vmail.*/ vmail/
rm -rf vmail.*
for db in amavisd iredadmin roundcubemail sogo vmail; do
    zcat ${db}_dump-*.sql.gz | mariadb $db
done 
