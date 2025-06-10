#!/usr/bin/env ruby

require_relative 'spec/spec_helper'

# Create models that exactly match your scenario
class CommunitySolutionEvaluator
  attr_accessor :id, :name

  def initialize(id, name)
    @id = id
    @name = name
  end
end

class TrustedCommunitySolutionEvaluation
  attr_accessor :id, :evaluator, :creator, :community_solution

  def initialize(id, evaluator, creator, community_solution)
    @id = id
    @evaluator = evaluator
    @creator = creator
    @community_solution = community_solution
  end
  
  def evaluator_id
    evaluator&.id
  end
  
  def creator_id
    creator&.id
  end
  
  def community_solution_id
    community_solution&.id
  end
end

class CommunitySolution
  attr_accessor :id, :user, :trusted_evaluations

  def initialize(id, user)
    @id = id
    @user = user
    @trusted_evaluations = []
  end
  
  def trusted_evaluation_ids
    trusted_evaluations.map(&:id)
  end
end

# Create serializers that exactly match your scenario
class CommunitySolutionEvaluatorSerializer
  include JSONAPI::Serializer
  
  set_type :'community-solution-evaluators'
  attributes :name
end

class TrustedCommunitySolutionEvaluationSerializer
  include JSONAPI::Serializer
  
  set_type :'trusted-community-solution-evaluations'
  belongs_to :community_solution, lazy_load_data: true
  belongs_to :creator, serializer: UserSerializer, lazy_load_data: true
  belongs_to :evaluator, serializer: CommunitySolutionEvaluatorSerializer, lazy_load_data: true

  attribute :created_at
  attribute :result
end

class CommunitySolutionSerializer
  include JSONAPI::Serializer
  
  set_type :'community-course-stage-solutions'
  has_many :trusted_evaluations, 
           serializer: TrustedCommunitySolutionEvaluationSerializer,
           lazy_load_data: true
end

# Create test data exactly like your scenario
evaluator = CommunitySolutionEvaluator.new('a02d6e8d-2b0b-46f7-a40e-218a4b1d97e7', 'Test Evaluator')
user = User.fake
solution = CommunitySolution.new('02f21945-ec8e-4928-b646-83e4fc78f354', user)

trusted_eval = TrustedCommunitySolutionEvaluation.new(
  '016aadcc-ff52-4ea2-bf3e-14355c6188d7', 
  evaluator, 
  user, 
  solution
)
trusted_eval.instance_variable_set(:@created_at, Time.now.iso8601)
trusted_eval.instance_variable_set(:@result, 'approved')

def trusted_eval.created_at
  @created_at
end

def trusted_eval.result
  @result
end

solution.trusted_evaluations = [trusted_eval]

puts "=== Testing your exact scenario ==="

# Test with your exact include string
serialized = CommunitySolutionSerializer.new(
  solution, 
  include: ['trusted_evaluations', 'trusted_evaluations.evaluator']
).serializable_hash

puts "\n=== SERIALIZED OUTPUT ==="
puts JSON.pretty_generate(serialized)

# Check the trusted evaluation in included section
if serialized[:included]
  te_included = serialized[:included].find { |inc| inc[:type] == :'trusted-community-solution-evaluations' }
  puts "\n=== TRUSTED EVALUATION ANALYSIS ==="
  puts "Trusted evaluation found: #{!te_included.nil?}"
  
  if te_included
    puts "Trusted evaluation content:"
    puts JSON.pretty_generate(te_included)
    
    evaluator_rel = te_included.dig(:relationships, :evaluator)
    puts "\nEvaluator relationship: #{evaluator_rel.inspect}"
    
    if evaluator_rel
      has_data = evaluator_rel.has_key?(:data)
      puts "Has evaluator data key: #{has_data}"
      puts "Evaluator data: #{evaluator_rel[:data].inspect}" if has_data
    end
  end
  
  # Check if evaluator is in included section
  evaluator_included = serialized[:included].find { |inc| inc[:type] == :'community-solution-evaluators' }
  puts "\nEvaluator in included section: #{!evaluator_included.nil?}"
  puts "Evaluator content: #{evaluator_included.inspect}" if evaluator_included
end