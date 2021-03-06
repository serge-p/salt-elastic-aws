{%- from 'java/settings.sls' import java with context %}

# require a source_url - there is no default download location for a jdk
{%- if java.source_url is defined %}

{{ java.prefix }}:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

unpack-jdk-tarball:
  cmd.run:
    - name: curl {{ java.dl_opts }} '{{ java.source_url }}' | tar xz --no-same-owner
    - cwd: {{ java.prefix }}
    - unless: test -d {{ java.java_real_home }}
    - require:
      - file: {{ java.prefix }}
  alternatives.install:
    - name: java-home-link
    - link: {{ java.java_home }}
    - path: {{ java.java_real_home }}
    - priority: 30
  file.symlink:
    - name: {{ java.java_home }}
    - target: /etc/alternatives/java-home-link
    - force: True 

{% for alt in ['java' , 'keytool', 'servertool'] %} 

install {{ alt }} alternatives:
  alternatives.install:
    - name: {{ alt }}
    - link: /usr/bin/{{ alt }}
    - path: {{ java.java_real_home }}/bin/{{ alt }}
    - priority: 18000

update {{ alt }} alternatives:
  alternatives.set:
    - name: {{ alt }}
    - path: {{ java.java_real_home }}/bin/{{ alt }}

{% endfor %}

include: 
  - java.env

{%- endif %}
