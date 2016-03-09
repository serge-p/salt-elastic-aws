{% set this       = 'shield' %}
{% set plugins    = [ 'license', 'shield' , 'cloud-aws' ] %}
{% set admin      = 'esadmin' %}
{% set adminpass  = 'test123' %}
{% set storepass  = 'supersecure' %}
{% set hostname   = grains['fqdn'] %}
{% for ifacename, interface in salt['network.interfaces']().iteritems() if interface.up == True and ifacename != 'lo' %}
{% set ip = interface.inet[0]['address'] %}
{% endfor %}


include: 
  - es

#############################################################
# Install plugins 
#############################################################



{% for plugin in plugins %} 

bin/plugin install {{ plugin }}:
  cmd.run:
    - cwd: '/usr/share/elasticsearch'
    - creates: /usr/share/elasticsearch/plugins/{{ plugin }}

{%endfor %}



#############################################################
# config part 
#############################################################



# create admin user  
#############################################################


useradd {{ admin }} -p {{ adminpass }} -r admin:
  cmd.run:
    - cwd: /usr/share/elasticsearch/bin/shield
    - creates: /etc/elasticsearch/shield/users

# Message authentication 
#############################################################


syskeygen && chown elasticsearch /etc/elasticsearch/shield/system_key:
  cmd.run: 
    - cwd: /usr/share/elasticsearch/bin/shield
    - creates: /etc/elasticsearch/shield/system_key



# SSL/TLS    
#############################################################




# Keytool part 
#############################################################



#
#keytool -importcert -keystore truststore.jks -file /etc/ssl/ca.crt -storepass {{ storepass }} -noprompt -trustcacerts:
#
keytool -importcert -keystore node01.jks -file /etc/ssl/ca.crt -alias my_ca -storepass {{ storepass }} -noprompt -trustcacerts:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - creates: /etc/elasticsearch/shield/node01.jks


keytool -genkey -alias node01 -keystore node01.jks -keyalg RSA -keysize 2048 -validity 3650 -noprompt -storepass {{ storepass }}:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - unless: keytool -list -keystore node01.jks -storepass {{ storepass }} |grep node01

keytool -certreq -alias node01 -keystore node01.jks -file node01.csr -noprompt -storepass {{ storepass }} -keyalg rsa:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - creates: /etc/elasticsearch/shield/node01.csr


openssl ca -in node01.csr -notext -out node01-signed.crt -config ca/caconfig.cnf -extensions v3_req -batch:
  cmd.run:
    - cwd: /etc/elasticsearch/shield
    - creates: /etc/elasticsearch/shield/node01-signed.crt


keytool -importcert -keystore node01.jks -file node01-signed.crt -alias server -storepass {{ storepass }} -noprompt:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - unless: keytool -list -keystore node01.jks -storepass {{ storepass }} |grep node01 



# Shield config block    
#############################################################


/etc/elasticsearch/elasticsearch.yml:
  file.blockreplace:
    - marker_start: "########## START managed {{ this }} -DO-NOT-EDIT-"
    - marker_end: "########## END managed zone {{ this }} --"
    - append_if_not_found: True
    - show_changes: True
    - content: | 
        shield.audit.enabled: true
        http.cors.allow-origin : "*"
        http.cors.allow-methods : OPTIONS, HEAD, GET, POST, PUT, DELETE
        http.cors.allow-headers : X-Requested-With,X-Auth-Token,Content-Type, Content-Length
        shield.ssl.keystore.path:          /etc/elasticsearch/shield/node01.jks 
        shield.ssl.keystore.password:      {{ storepass }}
        shield.ssl.keystore.key_password:  {{ storepass }}
        shield.transport.ssl: true
        shield.http.ssl: true
        shield.ssl.hostname_verification: false
        shield.ssl.hostname_verification.resolve_name: false


#############################################################
# Healthcheck part (now secured)  
#############################################################


#openssl s_client -connect 127.0.0.1:9300
#  cmd.run: 
#   - use_vt: true


#curl -u {{ admin }}:{{ adminpass }} -XGET 'http://{{ admin }}:{{ adminpass }}@localhost/':
#  cmd.run: 
#    - use_vt: true


