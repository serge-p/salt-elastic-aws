{% set this = 'elasticsearch' %}
{% set ES_HEAP_SIZE = (salt['grains.get']('mem_total')/2)|round|int|string + 'm' %}

#############################################################
# OS prereqs 
# https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-configuration.html
#############################################################


### Disable swap

swapoff -a:
  cmd.run

vm.swappiness:
  sysctl.present:
    - value: 1


### set vm.max_map_count according to config instructions

vm.max_map_count:
  sysctl.present:
    - value: 262144



#############################################################
# Install part 
#############################################################


{% if salt['grains.get']('os_family') == 'RedHat' %}
es_yum_repo:
  pkgrepo.managed:
    - name: elasticsearch
    - humanname: Elasticsearch repository for 2.x packages
    - baseurl: 'https://packages.elastic.co/elasticsearch/2.x/centos'
    - key_url: 'https://packages.elastic.co/GPG-KEY-elasticsearch'
    - gpgcheck: False
    - enabled: True
    - require_in:
      - pkg: es_install
    - watch_in:
      - pkg: es_install
{% endif %}

es_install:
  pkg.installed:
    - name: elasticsearch
  service:
    - running 
    - name: elasticsearch
    - enable: True
    - require:
        - pkg: elasticsearch
        - file: /etc/elasticsearch/elasticsearch.yml
        - file: /etc/sysconfig/elasticsearch 

#############################################################
# config part 
#############################################################


/etc/elasticsearch/elasticsearch.yml:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - makedirs: True
    - source: salt://es/files/elasticsearch.yml

/etc/sysconfig/elasticsearch: 
  file.blockreplace:
    - marker_start: "########## START managed {{ this }} -DO-NOT-EDIT-"
    - marker_end: "########## END managed zone {{ this }} --"
    - append_if_not_found: True
    - show_changes: True
    - content: | 
        export ES_HEAP_SIZE={{ ES_HEAP_SIZE }}



#############################################################
# Healthcheck part (plain)
#############################################################


{% for port in [ 9200 , 9300 ] %} 
es test connection on {{ port }}:
  module.run: 
    - name: network.connect
#    - host: {{ salt['network.ipaddrs']()|join }}
    - host: 127.0.0.1
    - port: {{ port }}
    - proto: tcp
{% endfor %}


curl localhost:9200/_nodes/stats/process?pretty:
  cmd.run: 
    - use_vt: true
    - unless: ls -ald /etc/elasticsearch/shield

