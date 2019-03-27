require "topological_inventory/openshift/operations/worker"

RSpec.describe TopologicalInventory::Openshift::Operations::Worker do
  let(:client) { double(:client) }

  describe "#run" do
    let(:messages) { [ManageIQ::Messaging::ReceivedMessage.new(nil, "ServicePlan.order", payload, SecureRandom.uuid)] }
    let(:task) { double("Task", :id => 1) }

    let(:service_plan) do
      TopologicalInventoryApiClient::ServicePlan.new(:id                  => "123",
                                                     :name                => "plan_name",
                                                     :source_id           => source.id,
                                                     :service_offering_id => service_offering.id)
    end
    let(:source) do
      TopologicalInventoryApiClient::Source.new(:id => "321")
    end
    let(:service_offering) do
      TopologicalInventoryApiClient::ServiceOffering.new(:id => "456", :name => "service_offering")
    end
    let(:payload) { {"service_plan_id" => service_plan.id.to_s, "order_params" => "order_params", "task_id" => task.id.to_s} }

    let(:service_catalog_client) { instance_double("ServiceCatalogClient") }
    let(:base_url_path) { "https://virtserver.swaggerhub.com/api/topological-inventory/v0.1/" }
    let(:service_plan_url) { URI.join(base_url_path, "service_plans/#{service_plan.id}").to_s }
    let(:source_url) { URI.join(base_url_path, "sources/#{source.id}").to_s }
    let(:service_offering_url) { URI.join(base_url_path, "service_offerings/#{service_offering.id}").to_s }
    let(:task_url) { URI.join(base_url_path, "tasks/#{task.id}").to_s }
    let(:headers) { {"Content-Type" => "application/json"} }

    before do
      require "active_support/json"
      require "active_support/core_ext/object/json" # required to get service_plan.to_json to work properly

      allow(ManageIQ::Messaging::Client).to receive(:open).and_return(client)
      allow(client).to receive(:close)
      allow(client).to receive(:subscribe_messages).and_yield(messages)
      allow(client).to receive(:ack)

      stub_request(:get, service_plan_url).with(:headers => headers).to_return(
        :headers => headers, :body => service_plan.to_json
      )
      stub_request(:get, source_url).with(:headers => headers).to_return(
        :headers => headers, :body => source.to_json
      )
      stub_request(:get, service_offering_url).with(:headers => headers).to_return(
        :headers => headers, :body => service_offering.to_json
      )

      allow(
        TopologicalInventory::Openshift::Operations::Core::ServiceCatalogClient
      ).to receive(:new).with(source.id).and_return(service_catalog_client)

      allow(service_catalog_client).to receive(:order_service_plan)
        .and_return(
          Kubeclient::Resource.new(
            :metadata => {
              :uid => "af01c63c-e479-4190-8054-9c5ba2e9ec81"
            },
            :status   => {
              :conditions => [
                Kubeclient::Resource.new(
                  :reason => "ProvisionedSuccessfully"
                )
              ]
            }
          )
        )

      stub_request(:patch, task_url).with(:headers => headers)
    end

    it "orders the service via the service catalog client" do
      expect(service_catalog_client).to receive(:order_service_plan).with("plan_name", "service_offering", "order_params")
      described_class.new.run
    end

    it "makes a patch request to the update task endpoint with the status and context" do
      expected_context = {
        :service_instance => {
          :source_id  => source.id,
          :source_ref => "af01c63c-e479-4190-8054-9c5ba2e9ec81"
        }
      }.to_json

      described_class.new.run
      expect(
        a_request(:patch, task_url).with(:body => {"status" => "ok", "state" => "completed", "context" => expected_context})
      ).to have_been_made
    end
  end
end
