module Types
  class QueryType < Types::BaseObject
    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :ping, String, null: false, description: 'Is this thing on?'

    def ping
      'Pong!'
    end

    field :record_id, RecordType, null: false,
                                  description: 'Retrieve one timdex record' do
      argument :id, String, required: true
    end

    def record_id(id:)
      result = Retrieve.new.fetch(id)
      result['hits']['hits'].first['_source']
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      raise GraphQL::ExecutionError, "Record '#{id}' not found"
    end

    field :search, SearchType, null: false,
                               description: 'Search for timdex records' do
      argument :searchterm, String, required: true
      argument :from, String, required: false, default_value: '0'

      # applied facets
      argument :content_type, String, required: false, default_value: nil
      argument :contributors, [String], required: false, default_value: nil
      argument :format, [String], required: false, default_value: nil
      argument :languages, [String], required: false, default_value: nil
      argument :literary_form, String, required: false, default_value: nil
      argument :source, String, required: false, default_value: 'All'
      argument :subjects, [String], required: false, default_value: nil
    end

    def search(searchterm:, from:, content_type:, contributors:, format:,
               languages:, literary_form:, source:, subjects:)
      query = {}
      query[:q] = searchterm

      query[:content_format] = format
      query[:content_type] = content_type
      query[:contributors] = contributors
      query[:language] = languages
      query[:literary_form] = literary_form
      query[:source] = source if source != 'All'
      query[:subject] = subjects

      results = Search.new.search(from, query)

      response = {}
      response[:hits] = results['hits']['total']
      response[:records] = results['hits']['hits'].map { |x| x['_source'] }
      response[:aggregations] = collapse_buckets(results['aggregations'])
      response
    end

    def collapse_buckets(es_aggs)
      {
        content_format: es_aggs['content_format']['buckets'],
        content_type: es_aggs['content_type']['buckets'],
        contributors: es_aggs['contributors']['contributor_names']['buckets'],
        languages: es_aggs['languages']['buckets'],
        literary_form: es_aggs['literary_form']['buckets'],
        source: es_aggs['source']['buckets'],
        subjects: es_aggs['subjects']['buckets']
      }
    end
  end
end
