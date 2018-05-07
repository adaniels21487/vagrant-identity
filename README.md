This is a [Vagrant](https://www.vagrantup.com/) Environment including a [Directory/LDAP](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol) Server and a SAML Identity Provider (IdP).
It has been designed to provide a lab environment that developers can test their SAML Service Provider (Web apps) applications against.

This environment was based on the works of [rgl](https://github.com/rgl/ldap-vagrant), and [jnyryan](https://github.com/jnyryan/vagrant-simplesamlphp.git) was modified and updated with the help of many blog posts on the internet.

This uses the [slapd](http://www.openldap.org/software/man.cgi?query=slapd) daemon from [OpenLDAP](http://www.openldap.org/) and [SimpleSAMLphp](https://simplesamlphp.org/docs/stable/simplesamlphp-idp) configured as an IdP.

LDAP is described at [RFC 4510 (Technical Specification)](https://tools.ietf.org/html/rfc4510).
SAML is described at [RFC 7522 (Technical Specification)](https://tools.ietf.org/html/rfc7522).

# Usage

Run `vagrant up` to configure the `identity.example.com` LDAP server environment.

Configure your systems `/etc/hosts` file with the `identity.example.com` domain:

    192.168.174.91 identity.example.com

#### NOT PRODUCTION READY
This box is not built for production. It is designed for a closed lab environment. All passwords are set to 'password' and other bad security practises.

## LDAP
Several additonal/custom attributes have been created including:

- agency - A Tenant identifier.
- sAMAccountName - UserID in Active Directory.
- userPrincipalName - user@domain type attribute, used in Active Directory.

To support tenancy, each LDAP user contains an attribute agency, this field defines the tenant that a user is a member of. In this example directory, each user (admin+user) has had its agency field populated with tenantX where X is thier user number.
The environment comes pre-configured with the following user entries:

- Agency 1
  - uid=user1,ou=agency1,ou=users,dc=example,dc=com
  - uid=admin1,ou=agency1,ou=users,dc=example,dc=com
- Agency 2
  - uid=user2,ou=agency2,ou=users,dc=example,dc=com
  - uid=admin2,ou=agency2,ou=users,dc=example,dc=com
- Agency 3
  - uid=user3,ou=agency3,ou=users,dc=example,dc=com
  - uid=admin3,ou=agency3,ou=users,dc=example,dc=com

The password for all users accounts is 'password', including the Administrator DN (cn=admin,dc=example,dc=com).

Each userX is a member of the users group (cn=user,ou=groups,dc=example,dc=com) and each adminX user is a member of the admin group ((cn=admin,ou=groups,dc=example,dc=com)).

## SAML
SimpleSAMLphp has been configured as an IdP authenticating against the LDAP database.
Basic configuration and setup have been performed using general default values, please feel free to [customise](https://simplesamlphp.org/docs/stable/simplesamlphp-install#section_7) this as required.

Its configuration is intentionally incomplete, it is waiting for you to configure your Web application as an SP.

Please consult the SimpleSAMLphp [documentation](https://simplesamlphp.org/docs/stable/simplesamlphp-idp#section_7), as well as the documentation for your SP application to complete this task.
