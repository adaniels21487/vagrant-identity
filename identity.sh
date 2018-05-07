#!/bin/bash
set -eux

config_organization_name=Example
config_fqdn=$(hostname --fqdn)
config_domain=$(hostname --domain)
config_domain_dc="dc=$(echo $config_domain | sed 's/\./,dc=/g')"
config_admin_dn="cn=admin,$config_domain_dc"
config_admin_password=password

echo "127.0.0.1 $config_fqdn" >>/etc/hosts

echo 'Acquire::http::Proxy "http://192.168.174.50:3142";' >/etc/apt/apt.conf.d/00aptproxy
apt-get update -y

apt-get install -y --no-install-recommends vim
cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
autocmd BufNewFile,BufRead Vagrantfile set ft=ruby
EOF

##############################################################
####################### CONFIGURE LDAP #######################
##############################################################

# these anwsers were obtained (after installing slapd) with:
#
#   #sudo debconf-show slapd
#   sudo apt-get install debconf-utils
#   # this way you can see the comments:
#   sudo debconf-get-selections
#   # this way you can just see the values needed for debconf-set-selections:
#   sudo debconf-get-selections | grep -E '^slapd\s+' | sort
debconf-set-selections <<EOF
slapd slapd/password1 password $config_admin_password
slapd slapd/password2 password $config_admin_password
slapd slapd/domain string $config_domain
slapd shared/organization string $config_organization_name
EOF

apt-get install -y --no-install-recommends slapd ldap-utils

# Add the memberof capability
# See: https://devopsideas.com/planning-of-ldap-dit-structure-and-config-of-overlays-access-ppolicy/
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /vagrant/etc/ldap/schema/memberOfmodule.ldif
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /vagrant/etc/ldap/schema/memberOfconfig.ldif
ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f /vagrant/etc/ldap/schema/refintmod.ldif
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /vagrant/etc/ldap/schema/refintconfig.ldif

# create the users container.
# NB the `cn=admin,$config_domain_dc` user was automatically created
#    when the slapd package was installed.
ldapadd -D $config_admin_dn -w $config_admin_password <<EOF
dn: ou=users,$config_domain_dc
objectClass: organizationalUnit
ou: users
EOF

# create each tenants container.
ldapadd -D $config_admin_dn -w $config_admin_password <<EOF
dn: ou=tenant1,ou=users,$config_domain_dc
objectClass: organizationalUnit
ou: tenant1
EOF
ldapadd -D $config_admin_dn -w $config_admin_password <<EOF
dn: ou=tenant2,ou=users,$config_domain_dc
objectClass: organizationalUnit
ou: tenant2
EOF
ldapadd -D $config_admin_dn -w $config_admin_password <<EOF
dn: ou=tenant3,ou=users,$config_domain_dc
objectClass: organizationalUnit
ou: tenant3
EOF

# create the groups container.
ldapadd -D $config_admin_dn -w $config_admin_password <<EOF
dn: ou=groups,$config_domain_dc
objectClass: organizationalUnit
ou: groups
EOF

# Add our groups.
ldapadd -D $config_admin_dn -w $config_admin_password <<EOF
dn: cn=admin,ou=groups,$config_domain_dc
objectClass: groupofnames
cn: admin
description: Administrative users
member: cn=admin,$config_domain_dc
EOF

ldapadd -D $config_admin_dn -w $config_admin_password <<EOF
dn: cn=user,ou=groups,$config_domain_dc
objectClass: groupofnames
cn: user
description: Unprivileged users
member: cn=admin,$config_domain_dc
EOF

# Set the admin password for the configuration DN.
ldapmodify -Y EXTERNAL -H ldapi:/// -D 'cn=config' <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcRootPW
olcRootPW: $(slappasswd -h {SSHA} -s config_admin_password)
EOF

# Create our custom schema
ldapmodify -Y EXTERNAL -H ldapi:/// -D "cn=schema,cn=config" -w $config_admin_password <<EOF
dn: cn=test,cn=schema,cn=config
changetype: add
objectClass: olcSchemaConfig
olcAttributeTypes: ( 1.2.3.4.5.6.1.2.1
  NAME ( 'agency' )
  DESC 'The tenant that the user belongs to'
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE
  USAGE userApplications )
olcAttributeTypes: ( 1.2.3.4.5.6.1.2.2
  NAME ( 'sAMAccountName' )
  DESC 'the AD User ID'
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE
  USAGE userApplications )
olcAttributeTypes: ( 1.2.3.4.5.6.1.2.3
  NAME ( 'userPrincipalName' )
  DESC 'AD Attribute'
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE
  USAGE userApplications )
olcObjectClasses: ( 1.2.3.4.5.6.1.1.1
  NAME 'testPerson'
  DESC 'Test Person'
  SUP ( inetOrgPerson )
  MUST ( sAMAccountName $ agency $ userPrincipalName ) )
EOF

# add users.
function add_user {
    local name=$1; shift
    local tenant=$1; shift
    local role=$1; shift
    ldapadd -D $config_admin_dn -w $config_admin_password <<EOF
dn: uid=$name,ou=$tenant,ou=users,$config_domain_dc
objectClass: testPerson
userPassword: $(slappasswd -s password)
uid: $name
mail: $name@$config_domain
cn: $name doe
givenName: $name
sn: doe
agency: $tenant
sAMAccountName: $name@$tenant.local
userPrincipalName: $name@$tenant.local
EOF

ldapmodify -D $config_admin_dn -w $config_admin_password <<EOF
dn: cn=$role,ou=groups,$config_domain_dc
changetype: modify
add: member
member: uid=$name,ou=users,$config_domain_dc
EOF
}
add_user admin1 tenant1 admin
add_user user1 tenant1 user
add_user admin2 tenant2 admin
add_user user2 tenant2 user
add_user admin3 tenant3 admin
add_user user3 tenant3 user

# show the configuration tree.
ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:/// -b cn=config dn | grep -v '^$'

# show the data tree.
ldapsearch -x -LLL -b $config_domain_dc dn | grep -v '^$'

# search for people and print some of their attributes.
ldapsearch -x -LLL -b $config_domain_dc '(objectClass=person)' cn samaccountname agency memberof

##############################################################
####################### CONFIGURE SAML #######################
##############################################################

####################
# required packages
apt-get install -y apache2 curl php libapache2-mod-php php-mcrypt php-xml php-mbstring php-curl php-memcache php-ldap memcached libapache2-mod-gnutls

####################
# SimpleSaml
# From: https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-simplesamlphp-for-saml-authentication-on-ubuntu-16-04
cd ~
wget https://simplesamlphp.org/download?latest
tar zxf download?latest
rm download?latest
mv simplesamlphp-* /var/simplesamlphp

# SSL
cd /var/simplesamlphp
mkdir -p cert
openssl req -x509 -batch -nodes -newkey rsa:2048 -keyout cert/server.pem -out cert/server.crt

# Config
cp /vagrant/etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/000-default.conf
cp /vagrant/etc/simplesamlphp/config/config.php /var/simplesamlphp/config/config.php
cp /vagrant/etc/simplesamlphp/config/authsources.php /var/simplesamlphp/config/authsources.php
cp /vagrant/etc/simplesamlphp/metadata/saml20-idp-hosted.php /var/simplesamlphp/metadata/saml20-idp-hosted.php
systemctl restart apache2
