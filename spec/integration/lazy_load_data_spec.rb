require "spec_helper"

RSpec.describe JSONAPI::Serializer do
  describe "lazy_load_data with includes" do
    let(:user) { User.fake }
    let(:movie) do
      mov = Movie.fake
      mov.owner = user
      mov
    end
    let(:actor) do
      act = Actor.fake
      act.movies = [movie]
      act
    end

    # Create a test serializer with lazy_load_data
    let(:test_movie_serializer) do
      Class.new do
        include JSONAPI::Serializer

        set_type :movie
        attributes :name, :year
        belongs_to :owner, serializer: UserSerializer, lazy_load_data: true
      end
    end

    let(:test_actor_serializer) do
      movie_serializer = test_movie_serializer
      Class.new do
        include JSONAPI::Serializer

        set_type :actor
        set_id :uid
        attributes :first_name, :last_name
        has_many :movies, serializer: movie_serializer, lazy_load_data: true
      end
    end

    context "when lazy_load_data is true and relationship is included" do
      it "should include the relationship data in the response" do
        serialized = test_movie_serializer.new(movie, include: [:owner]).serializable_hash.as_json

        expect(serialized["data"]["relationships"]["owner"]).to have_key("data")
        expect(serialized["data"]["relationships"]["owner"]["data"]).to eq({
          "id" => user.uid,
          "type" => "user"
        })
      end

      it "should include nested relationships when specified in includes" do
        serialized = test_actor_serializer.new(actor, include: ["movies", "movies.owner"]).serializable_hash.as_json

        # The actor should have movies relationship data
        expect(serialized["data"]["relationships"]["movies"]).to have_key("data")
        expect(serialized["data"]["relationships"]["movies"]["data"]).to eq([{
          "id" => movie.id,
          "type" => "movie"
        }])

        # The included movie should have owner relationship data
        movie_included = serialized["included"].find { |inc| inc["type"] == "movie" && inc["id"] == movie.id }
        expect(movie_included).not_to be_nil
        expect(movie_included["relationships"]["owner"]).to have_key("data")
        expect(movie_included["relationships"]["owner"]["data"]).to eq({
          "id" => user.uid,
          "type" => "user"
        })
      end
    end

    context "when lazy_load_data is true and relationship is not included" do
      it "should not include the relationship data in the response" do
        serialized = test_movie_serializer.new(movie).serializable_hash.as_json

        expect(serialized["data"]["relationships"]["owner"]).not_to have_key("data")
      end
    end
  end
end
