
PRODBIN = $(shell ../artifact.py filename ../component_versions.json zenoss-prodbin)
METRIC_CONSUMER = $(shell ../artifact.py filename ../component_versions.json zenoss.metric.consumer)
QUERY = $(shell ../artifact.py filename ../component_versions.json query)
PROTOCOLS = $(shell ../artifact.py filename ../component_versions.json zenoss-protocols)
PYNETSNMP = $(shell ../artifact.py filename ../component_versions.json pynetsnmp)
EXTJS = $(shell ../artifact.py filename ../component_versions.json zenoss-extjs)
ZEP = $(shell ../artifact.py filename ../component_versions.json zenoss-zep)
METRICSHIPPER = $(shell ../artifact.py filename ../component_versions.json metricshipper)
ZMINION = $(shell ../artifact.py filename ../component_versions.json zminion)
REDISMON = $(shell ../artifact.py filename ../component_versions.json redis-mon)
ZPROXY = $(shell ../artifact.py filename ../component_versions.json zproxy)
TOOLBOX = $(shell ../artifact.py filename ../component_versions.json zenoss.toolbox)
MIGRATION = $(shell ../artifact.py filename ../component_versions.json service-migration)

COMPONENTS = $(PRODBIN) $(METRIC_CONSUMER) $(QUERY) $(PROTOCOLS) $(PYNETSNMP) $(EXTJS) $(ZEP) $(METRICSHIPPER) $(ZMINION) $(REDISMON) $(ZPROXY) $(TOOLBOX) $(MIGRATION)

zenoss-prodbin: $(PRODBIN)

$(PRODBIN):
	@../artifact.py get ../component_versions.json zenoss-prodbin

zenoss.metric.consumer: $(METRIC_CONSUMER)

$(METRIC_CONSUMER):
	@../artifact.py get ../component_versions.json zenoss.metric.consumer

query: $(QUERY)

$(QUERY):
	@../artifact.py get ../component_versions.json query

zenoss-protocols: $(PROTOCOLS)

$(PROTOCOLS):
	@../artifact.py get ../component_versions.json zenoss-protocols

pynetsnmp: $(PYNETSNMP)

$(PYNETSNMP):
	@../artifact.py get ../component_versions.json pynetsnmp

zenoss-extjs: $(EXTJS)

$(EXTJS):
	@../artifact.py get ../component_versions.json zenoss-extjs

zenoss-zep: $(ZEP)

$(ZEP):
	@../artifact.py get ../component_versions.json zenoss-zep

metricshipper: $(METRICSHIPPER)

$(METRICSHIPPER):
	@../artifact.py get ../component_versions.json metricshipper

zminion: $(ZMINION)

$(ZMINION):
	@../artifact.py get ../component_versions.json zminion

redis-mon: $(REDISMON)

$(REDISMON):
	@../artifact.py get ../component_versions.json redis-mon

zproxy: $(ZPROXY)

$(ZPROXY):
	@../artifact.py get ../component_versions.json zproxy

zenoss.toolbox: $(TOOLBOX)

$(TOOLBOX):
	@../artifact.py get ../component_versions.json zenoss.toolbox

service-migration: $(MIGRATION)

$(MIGRATION):
	@../artifact.py get ../component_versions.json service-migration
