require 'spec_helper'

class TestContextualFinder < ShortestPath::Finder
    def refresh_context( node, context)
      count = context[:edges_count] ? context[:edges_count] : 0
      return { :edges_count => (count + 1)}
    end

    def follow_way?(node, destination, weight, context={})
      return context[:edges_count].nil? || context[:edges_count] < 3
    end

end

describe ShortestPath::Finder do
  let(:graph) {
    {   :a => { :e => 3, :b => 1, :c => 3 },
        :b => { :e => 1, :a => 1, :c => 3, :d => 5 },
        :c => { :a => 3, :b => 3, :d => 1, :s => 3 },
        :d => { :b => 5, :c => 1, :s => 1 },
        :e => { :a => 3, :b => 1 },
        :s => { :c => 3, :d => 1 } }
  }

  def graph_sample( size)
      hash = {}
      0.upto( size ) do |i|
        0.upto( size ) do |j|
            hash[ "#{i}-#{j}" ] = {} if hash[ "#{i}-#{j}" ].nil?
            node_neighbors = hash[ "#{i}-#{j}" ]
            if i<size
                node_neighbors[ "#{i+1}-#{j}" ] = 1

                # reverse link
                hash[ "#{i+1}-#{j}" ] = {} if hash[ "#{i+1}-#{j}" ].nil?
                hash[ "#{i+1}-#{j}" ][ "#{i}-#{j}" ] = 1
            end
            if j<size
                node_neighbors[ "#{i}-#{j+1}" ] = 1

                # reverse link
                hash[ "#{i}-#{j+1}" ] = {} if hash[ "#{i}-#{j+1}" ].nil?
                hash[ "#{i}-#{j+1}" ][ "#{i}-#{j}" ] = 1
            end
        end
      end
      hash
  end

  def contextual_shortest_path(source, destination, given_graph = graph)
    TestContextualFinder.new(source, destination).tap do |shortest_path|
      shortest_path.ways_finder = Proc.new { |node| given_graph[node] }
    end.path
  end

  it "should produce test graph" do
    my_graph = graph_sample(600)
    start = Time.now
    result = shortest_path( "150-150", "300-300", my_graph)
    #puts result.inspect
    expect(Time.now-start).to be < 5    
  end

  context "when using an edge_count filter in context " do
      it "should find shortest path in an exemple" do
        contextual_shortest_path(:e, :s).should == [:e, :b, :c, :d, :s]
      end
  end

  def shortest_path(source, destination, given_graph = graph)
    ShortestPath::Finder.new(source, destination).tap do |shortest_path|
      shortest_path.ways_finder = Proc.new { |node| given_graph[node] }
    end.path
  end

  it "should find shortest path in an exemple" do
    shortest_path(:e, :s).should == [:e, :b, :c, :d, :s]
  end

  it "should return empty array when unknown start or end" do
    shortest_path(:e, :unknown).should be_empty
    shortest_path(:unknown, :s).should be_empty
    shortest_path(:unknown, :unknown2).should be_empty
  end

  it "should find trivial solution" do
    shortest_path(:a, :b).should == [:a, :b]
  end

  it "should return empty array when graph is not connex" do
    not_connex = graph.clone
    not_connex[:d].delete(:s)
    not_connex[:c].delete(:s)

    shortest_path(:e, :s, not_connex).should be_empty
  end

  subject {
    ShortestPath::Finder.new(:e, :s).tap do |shortest_path|
      shortest_path.ways_finder = Proc.new {  |node| graph[node] }
    end
  }

  describe "begin_at" do

    let(:expected_time) { Time.now }

    it "should be defined when path starts" do
      Time.stub :now => expected_time
      subject.path
      subject.begin_at.should == expected_time
    end

  end

  describe "end_at" do

    let(:expected_time) { Time.now }

    it "should be defined when path ends" do
      Time.stub :now => expected_time
      subject.path
      subject.end_at.should == expected_time
    end

  end

  describe "duration" do

    it "should be nil before path is search" do
      subject.duration.should be_nil
    end

    let(:time) { Time.now }

    it "should be difference between Time.now and begin_at when path isn't ended'" do
      Time.stub :now => time
      subject.stub :begin_at => time - 2, :end_at => nil
      subject.duration.should == 2
    end

    it "should be difference between end_at and begin_at when available" do
      subject.stub :begin_at => time - 2, :end_at => time
      subject.duration.should == 2
    end

  end

  describe "timeout?" do

    before(:each) do
      subject.timeout = 2
    end

    it "should be false without timeout" do
      subject.timeout = nil
      subject.should_not be_timeout
    end

    it "should be false when duration is lower than timeout" do
      subject.stub :duration => (subject.timeout - 1)
      subject.should_not be_timeout
    end

    it "should be true when duration is greater than timeout" do
      subject.stub :duration => (subject.timeout + 1)
      subject.should be_timeout
    end

  end

  describe "path" do

    it "should raise a Timeout::Error when timeout?" do
      subject.stub :timeout? => true
      lambda { subject.path }.should raise_error(ShortestPath::TimeoutError)
    end

  end

end
