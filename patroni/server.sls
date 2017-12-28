{%- from "patroni/map.jinja" import server with context %}
{%- if server.enabled %}

patroni_packages:
  pkg.installed:
  - names: {{ server.patroni_deps }}
  pip.installed:
  - names: {{ server.pip_patroni_deps }}

patroni_git:
  git.latest:
    - name: {{ server.git_patroni_url }}
    - branch: {{ server.git_patroni_branch }}
    - target: {{ server.git_patroni_dest }}
    - force_checkout: True
    - require:
      - pkg: patroni_packages

{%- if grains.os_family == "Debian" %}

postgresql_data_dir:
  file.directory:
    - name: {{ server.dir.data }}
    - user: postgres
    - group: postgres
    - mode: 755
    - makedirs: True

patroni_config_dir:
  file.directory:
    - name: {{ server.dir.config }}
    - user: postgres
    - group: postgres
    - mode: 755
    - makedirs: True

patroni_postgresql_config:
  file.managed:
  - name: {{ server.dir.config }}/postgresql.yml
  - source: salt://patroni/files/postgresql0.yml
  - template: jinja
  - user: postgres
  - group: postgres
  - mode: 600
  - require:
    - file: patroni_config_dir
    - file: postgresql_data_dir

patroni_deployment_script:
  file.managed:
  - name: {{ server.dir.psql_source }}/patroni.sh
  - source: salt://patroni/files/patroni.sh
  - template: jinja
  - user: postgres
  - group: postgres
  - mode: 600
  - require:
    - file: patroni_config_dir
    - file: postgresql_data_dir

patroni_service_config:
  file.managed:
  - name: /etc/systemd/system/patroni.service
  - source: salt://patroni/files/patroni.service
  - template: jinja
  - user: postgres
  - group: postgres
  - mode: 600
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: patroni_service_config
  - require:
    - file: patroni_deployment_script

patroni_service:
  service.running:
  - name: patroni
  - enable: true
  - reload: true
  - watch:
    - file: patroni_service_config
  - require:
    - file: patroni_service_config

{%- endif %}

{%- endif %}
