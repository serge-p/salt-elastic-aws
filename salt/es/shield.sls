{% set this       = 'shield' %}
{% set hostname   = grains['fqdn'] %}
{% set plugins    = [ 'license', 'shield' , 'cloud-aws' ] %}
{% set admin      = 'esadmin' %}
{% set adminpass  = 'test123' %}
{% set storepass  = 'supersecure' %}

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


esusers useradd {{ admin }} -p {{ adminpass }} -r admin:
  cmd.run:
    - cwd: /usr/share/elasticsearch/bin/shield
    - creates: /etc/elasticsearch/shield/users

# Message authentication 
#############################################################


/usr/share/elasticsearch/bin/shield/syskeygen && chown elasticsearch /etc/elasticsearch/shield/system_key:
  cmd.run: 
    - cwd: /usr/share/elasticsearch/bin/shield
    - creates: /etc/elasticsearch/shield/system_key




# Keytool part 
#############################################################




keytool -importcert -keystore {{ hostname }}.jks -file ca/certs/cacert.pem -alias {{ hostname }}-ca -storepass {{ storepass }} -noprompt -trustcacerts:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - creates: /etc/elasticsearch/shield/{{ hostname }}.jks


keytool -genkey -alias {{ hostname }} -keystore {{ hostname }}.jks -keyalg RSA -keysize 2048 -validity 3650 -noprompt -storepass {{ storepass }} -keypass {{ storepass }} -dname "CN=testcluster, OU=test, O=SVP Consulting, L=Boston, ST=MA, C=US" :
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - unless: keytool -list -keystore {{ hostname }}.jks -storepass {{ storepass }} |grep {{ hostname }}

keytool -certreq -alias {{ hostname }} -keystore {{ hostname }}.jks -file {{ hostname }}.csr -noprompt -storepass {{ storepass }} -keyalg rsa:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - creates: /etc/elasticsearch/shield/{{ hostname }}.csr


openssl ca -in {{ hostname }}.csr -notext -out {{ hostname }}-signed.crt -config ca/caconfig.cnf -extensions v3_req -batch:
  cmd.run:
    - cwd: /etc/elasticsearch/shield
    - creates: /etc/elasticsearch/shield/{{ hostname }}-signed.crt


keytool -importcert -keystore {{ hostname }}.jks -file {{ hostname }}-signed.crt -alias {{ hostname }} -storepass {{ storepass }} -noprompt:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - unless: keytool -list -keystore {{ hostname }}.jks -storepass {{ storepass }} |grep {{ hostname }} 



# Shield config block    
#############################################################


/etc/elasticsearch/elasticsearch.yml shield configuration:
  file.blockreplace:
    - name: /etc/elasticsearch/elasticsearch.yml
    - marker_start: "########## START managed zone {{ this }} -DO-NOT-EDIT-"
    - marker_end: "########## END managed zone {{ this }} --"
    - append_if_not_found: True
    - show_changes: True
    - content: | 
        shield.audit.enabled: true
        shield.ssl.keystore.path:          /etc/elasticsearch/shield/{{ hostname }}.jks 
        shield.ssl.keystore.password:      {{ storepass }}
        shield.ssl.keystore.key_password:  {{ storepass }}
        shield.transport.ssl: true
        shield.http.ssl: true
        shield.ssl.hostname_verification: false
        shield.ssl.hostname_verification.resolve_name: false

# Restart service   
#############################################################


restart elasticsearch: 
  service.running:
    - name: elasticsearch
    - enable: True
    - watch: 
      - file: /etc/elasticsearch/elasticsearch.yml


#############################################################
# Healthcheck part TODO  
#############################################################


#openssl s_client -connect 127.0.0.1:9300
#  cmd.run: 
#   - use_vt: true


#curl -u {{ admin }}:{{ adminpass }} -XGET 'http://{{ admin }}:{{ adminpass }}@localhost/':
#  cmd.run: 
#    - use_vt: true


