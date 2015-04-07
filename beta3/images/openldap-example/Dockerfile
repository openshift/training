#
# This image is an openldap configuration that provides the users referenced
# from the OpenShift Enterprise 3.0 beta3 training materials:
# https://github.com/openshift/training/blob/master/beta-3-setup.md
#
# The standard name for this image is openshift/beta3-openldap-example

FROM centos:centos7

RUN yum -y install findutils && yum clean all
RUN yum -y install nss-pam-ldapd openldap-servers openldap-clients && yum clean all
RUN cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG 
RUN chown ldap. /var/lib/ldap/DB_CONFIG 

COPY *.ldif /tmp/
COPY background_slapd.sh /tmp/

# openldap has to be running in order to import the schema and base
# configuration.
RUN /tmp/background_slapd.sh && \
    cd /tmp && \
      ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif && \
      ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif  && \
      ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif && \
      ldapmodify -Y EXTERNAL -H ldapi:/// -f chdomain.ldif && \ 
      ldapadd -x -D cn=Manager,dc=example,dc=com -w redhat -f basedomain.ldif && \
      ldapadd -x -D cn=Manager,dc=example,dc=com -w redhat -f users.ldif

EXPOSE 389
CMD /usr/sbin/slapd -u ldap -h 'ldap:/// ldapi:///' -d stats
