{% if not helpers.empty('OPNsense.multihop.general.enabled') %}

multihop_enable="YES"
multihop_pidfile="/var/run/multihop.pid"

{% else %}
multihop_enable="NO"
{% endif %}
