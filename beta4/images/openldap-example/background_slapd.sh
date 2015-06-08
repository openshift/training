#!/bin/bash
/usr/sbin/slapd -u ldap -h 'ldap:/// ldapi:///' -d trace &

# FIXME: wait for it to start
sleep 2
