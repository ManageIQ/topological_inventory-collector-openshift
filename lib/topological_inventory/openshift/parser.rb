require "topological_inventory/providers/common/collector/parser"
require "more_core_extensions/core_ext/string/iec60027_2"
require "more_core_extensions/core_ext/string/decimal_suffix"

module TopologicalInventory::Openshift
  class Parser < TopologicalInventory::Providers::Common::Collector::Parser
    require "topological_inventory/openshift/parser/image"
    require "topological_inventory/openshift/parser/pod"
    require "topological_inventory/openshift/parser/namespace"
    require "topological_inventory/openshift/parser/node"
    require "topological_inventory/openshift/parser/resource_quota"
    require "topological_inventory/openshift/parser/template"
    require "topological_inventory/openshift/parser/cluster_service_class"
    require "topological_inventory/openshift/parser/cluster_service_plan"
    require "topological_inventory/openshift/parser/service_instance"

    include Image
    include Pod
    include Namespace
    include Node
    include ResourceQuota
    include Template
    include ClusterServiceClass
    include ClusterServicePlan
    include ServiceInstance

    attr_accessor :openshift_host, :openshift_port

    def initialize(openshift_host:, openshift_port: 8443)
      super()
      self.openshift_host = openshift_host
      self.openshift_port = openshift_port
    end

    private

    def parse_base_item(entity)
      {
        :name               => entity.metadata.name,
        :resource_version   => entity.metadata.resourceVersion,
        :resource_timestamp => resource_timestamp,
        :source_created_at  => entity.metadata.creationTimestamp,
        :source_ref         => entity.metadata.uid
      }
    end

    def archive_entity(inventory_object, entity)
      source_deleted_at = entity.metadata&.deletionTimestamp || Time.now.utc
      inventory_object.source_deleted_at = source_deleted_at
    end

    def lazy_find_namespace(name)
      return if name.nil?

      TopologicalInventoryIngressApiClient::InventoryObjectLazy.new(
        :inventory_collection_name => :container_projects,
        :reference                 => {:name => name},
        :ref                       => :by_name,
      )
    end

    def lazy_find_node(name)
      return if name.nil?

      TopologicalInventoryIngressApiClient::InventoryObjectLazy.new(
        :inventory_collection_name => :container_nodes,
        :reference                 => {:name => name},
        :ref                       => :by_name,
      )
    end

    def parse_quantity(quantity)
      return if quantity.nil?

      begin
        quantity.iec_60027_2_to_i
      rescue StandardError
        quantity.decimal_si_to_f
      end
    end
  end
end
