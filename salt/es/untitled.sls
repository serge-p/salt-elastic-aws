{% for ifacename, interface in salt['network.interfaces']().iteritems() if interface.up == True %}
{% if not salt['network.is_loopback'](interface.inet[0]['address']) %}
{% set ip = interface.inet[0]['address'] %}
{% endif %}
{% endfor %}


#'keytool -genkey -alias node01 -keystore node01.jks -keyalg RSA -keysize 2048 -validity 3650 -ext san=dns:ip-172-31-12-104.ec2.internal,ip:172.31.12.104 -noprompt -storepass {{ storepass }}':
# cmd.run: 
#    - cwd: /etc/elasticsearch/shield
#    - creates: /etc/elasticsearch/shield/node01.csr


#'keytool -certreq -alias node01 -keystore node01.jks -file node01.csr -noprompt -storepass {{ storepass }} -keyalg rsa -ext san=dns:{{ hostname }},ip:{{ ip }}':
#  cmd.run: 
#    - cwd: /etc/elasticsearch/shield
#    - creates: /etc/elasticsearch/shield/node01.csr
