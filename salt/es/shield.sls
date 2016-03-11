{% set this       = 'shield' %}
{% set hostname   = grains['fqdn'] %}
{% set plugins    = [ 'license', 'shield' , 'cloud-aws' ] %}
{% set admin      = 'esadmin' %}
{% set adminpass  = 'test123' %}
{% set storepass  = 'supersecure' %}


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


/usr/share/elasticsearch/bin/shield/esusers useradd {{ admin }} -p {{ adminpass }} -r admin:
  cmd.run:
    - cwd: /usr/share/elasticsearch/bin/shield
    - unless: cat /etc/elasticsearch/shield/users |grep {{ admin }}

# Message authentication 
#############################################################


/usr/share/elasticsearch/bin/shield/syskeygen && chown elasticsearch /etc/elasticsearch/shield/system_key:
  cmd.run: 
    - cwd: /usr/share/elasticsearch/bin/shield
    - creates: /etc/elasticsearch/shield/system_key




# Keytool part
# reference: https://www.elastic.co/guide/en/shield/current/ssl-tls.html#create-truststore 
#############################################################



keytool -importcert -keystore truststore.jks  -file ca/certs/cacert.pem -alias {{ hostname }}-ca -storepass {{ storepass }} -noprompt -trustcacerts:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - unless: keytool -list -keystore truststore.jks -storepass {{ storepass }} |grep {{ hostname }}-ca 


keytool -importcert -keystore {{ hostname }}.jks -file ca/certs/cacert.pem -alias {{ hostname }}-ca -storepass {{ storepass }} -noprompt -trustcacerts:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - creates: /etc/elasticsearch/shield/{{ hostname }}.jks


keytool -genkey -alias {{ hostname }}-key -keystore {{ hostname }}.jks -keyalg RSA -keysize 2048 -validity 3650 -noprompt -storepass {{ storepass }} -keypass {{ storepass }} -dname "CN=testcluster, OU=test, O=SVP Consulting, L=Boston, ST=MA, C=US" :
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - unless: keytool -list -keystore {{ hostname }}.jks -storepass {{ storepass }} |grep {{ hostname }}-key


keytool -certreq -alias {{ hostname }}-key -keystore {{ hostname }}.jks -file {{ hostname }}.csr -noprompt -storepass {{ storepass }} -keyalg rsa:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - creates: /etc/elasticsearch/shield/{{ hostname }}.csr


openssl ca -in {{ hostname }}.csr -notext -out {{ hostname }}-signed.crt -config ca/caconfig.cnf -extensions v3_req -batch:
  cmd.run:
    - cwd: /etc/elasticsearch/shield
    - unless: cat /etc/elasticsearch/shield/{{ hostname }}-signed.crt |grep CERT


keytool -importcert -keystore {{ hostname }}.jks -file {{ hostname }}-signed.crt -alias {{ hostname }}-crt -storepass {{ storepass }} -noprompt:
  cmd.run: 
    - cwd: /etc/elasticsearch/shield
    - unless: keytool -list -keystore {{ hostname }}.jks -storepass {{ storepass }} |grep {{ hostname }}-crt 






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
        discovery.type: ec2
        discovery.ec2.groups: es
        network.host: [ _ec2_ , _local_ ]
        node.data: true
        node.master: true
        shield.audit.enabled: true
        shield.ssl.truststore.path:        /etc/elasticsearch/shield/truststore.jks
        shield.ssl.truststore.password:    {{ storepass }}
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



curl -k -u {{ admin }}:{{ adminpass }} -XGET 'https://{{ admin }}:{{ adminpass }}@localhost:9200/':
  cmd.run: 
    - use_vt: true

