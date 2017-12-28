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

init_postgresql_cluster:
  postgres_cluster.present:
  - name: main
  - version: "{{ server.version }}"
  - datadir: "{{ server.dir.data }}"
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - require:
    - pkg: postgresql_packages
  - require_in:
    - file: {{ server.dir.config }}/pg_hba.conf
    - file: {{ server.dir.config }}/postgresql.conf

postgresql_data_dir:
  file.directory:
    - name: {{ server.dir.data }}
    - user: postgres
    - group: postgres
    - mode: 755
    - makedirs: True

patroni_config:
  file.directory:
    - name: {{ server.dir.config }}
    - user: postgres
    - group: postgres
    - mode: 755
    - makedirs: True

postgresql_patroni_config:
  file.managed:
  - name: {{ server.dir.config }}/postgresql.yml
  - source: salt://patroni/files/postgresql0.yml
  - template: jinja
  - user: postgres
  - group: postgres
  - mode: 600
  - require:
    - file: patroni_config

{{ server.dir.config }}/postgresql.conf:
  file.managed:
  - source: salt://postgresql/files/{{ server.version }}/postgresql.conf.{{ grains.os_family }}
  - template: jinja
  - user: postgres
  - group: postgres
  - defaults:
    postgresql_version: {{ server.version }}
  - mode: 600

{%- endif %}

/root/.pgpass:
  file.managed:
  - source: salt://postgresql/files/pgpass
  - template: jinja
  - user: root
  - group: root
  - mode: 600

{%- if grains.os_family == "Debian" %}

postgresql_service:
  service.running:
  - name: {{ server.service }}
  - enable: true
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - watch:
    - file: {{ server.dir.config }}/pg_hba.conf
    - file: {{ server.dir.config }}/postgresql.conf
  - require:
    - file: /root/.pgpass

{%- for database_name, database in server.get('database', {}).iteritems() %}
  {%- include "postgresql/_database.sls" %}

  {%- for extension_name, extension in database.get('extension', {}).iteritems() %}
    {%- if extension.enabled %}
    {%- if extension.get('pkgs', []) %}

postgresql_{{ extension_name }}_extension_packages:
  pkg.installed:
  - names: {{ pkgs }}

    {%- endif %}

database_{{ database_name }}_{{ extension_name }}_extension_present:
  postgres_extension.present:
  - name: {{ extension_name }}
  - maintenance_db: {{ database_name }}
  - user: postgres
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - require:
    - postgres_database: postgresql_database_{{ database_name }}

    {%- else %}

database_{{ database_name }}_{{ extension_name }}_extension_absent:
  postgres_extension.present:
  - name: {{ extension_name }}
  - maintenance_db: {{ database_name }}
  - user: postgres
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - require:
    - postgres_database: postgresql_database_{{ database_name }}

    {%- endif %}
  {%- endfor %}
{%- endfor %}

{%- endif %}

postgresql_dirs:
  file.directory:
  - names:
    - /root/postgresql/backup
    - /root/postgresql/flags
    - /root/postgresql/data
    - /root/postgresql/scripts
  - mode: 700
  - user: root
  - group: root
  - makedirs: true
  - require:
    - pkg: postgresql_packages

{%- if server.initial_data is defined %}

{%- set engine = server.initial_data.get("engine", "barman") %}

/root/postgresql/scripts/restore_wal.sh:
  file.managed:
  - source: salt://postgresql/files/restore_wal.sh
  - mode: 770
  - template: jinja
  - require:
    - file: postgresql_dirs

restore_postgresql_server:
  cmd.run:
  - name: /root/postgresql/scripts/restore_wal.sh
  - unless: "[ -f /root/postgresql/flags/restore_wal-done ]"
  - cwd: /root
  - require:
    - file: /root/postgresql/scripts/restore_wal.sh

{%- endif %}

{%- endif %}