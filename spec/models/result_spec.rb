require 'spec_helper'

describe Result do
  attr_reader :results, :work, :school, :errands, :walk, :bike, :mile, :earth_day_2011, 
    :train, :car, :bus, :bike_to_school,
    :palo_alto, :sunnyvale, :users, :user1, :user2, :user3, :user4, :user5, :user6, :user7, :user8, 
    :user9, :user10, :user_result

  before do
    @earth_day_2011 = Date.new(2011, 4, 22)
    @work = Destination.find_by_name("Work")
    @work.should_not be_nil
    @school = Destination.find_by_name("School")
    @school.should_not be_nil
    @errands = Destination.find_by_name("Errands & Other")
    @errands.should_not be_nil
    @bus = Mode.find_by_name("Bus")
    @bus.should_not be_nil
    @walk = Mode.find_by_name("Walk")
    @walk.should_not be_nil
    @bike = Mode.find_by_name("Bike")
    @bike.should_not be_nil
    @train = Mode.find_by_name("Train")
    @train.should_not be_nil
    @car = Mode.find_by_name("Drove Car Alone")
    @car.should be_present
    @mile = Unit.find_by_name("Mile")
    @mile.should_not be_nil
    @sunnyvale = Community.find_by_name("Sunnyvale")
    @sunnyvale.should be_present
    @palo_alto = Community.find_by_name("Palo Alto")
    @palo_alto.should be_present

    @results = Result.new
  end

  describe "#calculate_stats_for_user(user)" do
    attr_reader :user

    describe "when a user has 5 or more trips" do
      before do
        @user = User.make
        @user.save!
        user.baseline.update_attributes!(
          :work_green => 0,    :work_alone => 10,
          :school_green => 10, :school_alone => 0,
          :errands_green => 0, :errands_alone => 15
        )
        user.baseline.current_total_miles.should == 35.0
        user.baseline.current_green_miles.should == 10.0

        add_trips_to_user(@user, :mode => bike, :destination => work, :distances => [2.0]*5)
        add_trips_to_user(@user, :mode => walk, :destination => work, :distances => [0.5]*5)
        add_trips_to_user(@user, :mode => bus,  :destination => work, :distances => [8.0]*5)
        add_trips_to_user(@user, :mode => car,  :destination => work, :distances => [3.0, 3.0])
        @user.community = sunnyvale
        @user.save!

        @user_result = results.calculate_stats_for_user(@user)
      end

      it "should include stats fields for the user" do
        user_result[:walk_mileage].should == 2.5
        user_result[:bus_mileage].should == 40.0
        user_result[:bike_mileage].should == 10.0
        user_result[:train_mileage].should == 0.0
        user_result[:community_name].should == sunnyvale.name
        user_result[:baseline_pct_green].should == 10.0 / 35.0
        user_result[:total_green_miles].should == 40.0 + 10.0 + 2.5
        user_result[:total_miles].should == 40.0 + 10.0 + 2.5 + 6.0
        user_result[:total_green_trips].should == 15
        actual_pct = (40.0 + 10.0 + 2.5) / (40.0 + 10.0 + 2.5 + 6.0)
        user_result[:actual_pct_green].should == actual_pct
        user_result[:pct_improvement].should == actual_pct - (10.0 / 35.0)
      end
    end

    description "when user has fewer than 5 trips" do
      it "should return nil" do
        user = User.make
        user.save!
        add_trips_to_user(@user, :mode => bike, :destination => work, :distances => [1.0, 2.0])
        user.trips.count.should == 2
        @results.calculate_stats_for_user(user).should be_nil
      end
    end
  end

  describe "when there are several users" do
    before do
      @users = [
        @user0  = user_with_trips(:mode => bike, :destination => work,    :community => sunnyvale, :distances => [0.5]*5),
        @user1  = user_with_trips(:mode => bike, :destination => work,    :community => sunnyvale, :distances => [1.0]*5),
        @user2  = user_with_trips(:mode => walk, :destination => school,  :community => sunnyvale, :distances => [2.0]*5),
        @user3  = user_with_trips(:mode => bike, :destination => work,    :community => sunnyvale, :distances => [3.0]*5),
        @user4  = user_with_trips(:mode => walk, :destination => school,  :community => sunnyvale, :distances => [5.0]*5),
        @user5  = user_with_trips(:mode => bike, :destination => errands, :community => sunnyvale, :distances => [4.0]*5),
        @user6  = user_with_trips(:mode => bike, :destination => work,    :community => palo_alto, :distances => [1.1]*5),
        @user7  = user_with_trips(:mode => walk, :destination => school,  :community => palo_alto, :distances => [2.1]*5),
        @user8  = user_with_trips(:mode => bike, :destination => work,    :community => palo_alto, :distances => [3.1]*5),
        @user9  = user_with_trips(:mode => walk, :destination => school,  :community => palo_alto, :distances => [5.1]*5),
        @user10 = user_with_trips(:mode => bike, :destination => errands, :community => palo_alto, :distances => [4.1]*5),
        @user11 = user_with_trips(:mode => bike, :destination => errands, :community => palo_alto, :distances => [1.0, 1.0]),
      ]
    end

    describe "#user_results" do
      it "should return an array of results hashes for all users who have 5 or more trips" do
        @results.user_results.size.should == 11
        @results.user_results.each do |res|
          res.keys.should =~ [
            :"drove car alone_mileage",
            :train_mileage,
            :community_name,
            :carpool_mileage,
            :actual_pct_green,
            :baseline_pct_green,
            :pct_improvement,
            :walk_mileage,
            :total_green_miles,
            :bus_mileage,
            :"small electric vehicle_mileage",
            :user,
            :total_miles,
            :bike_mileage,
            :total_green_trips
          ]
        end
      end
    end

    describe "#users_by_mileage" do

      def ids_by_index(*args)
        args.map {|index| users[index].id}
      end

      it "should return the users in descending order of green miles traveled" do
        results.users_by_mileage.map {|res| res[:user].id}.should == ids_by_index(9,4,10,5,8,3,7,2,6,1,0)
      end

      it "should return the users in descending order of green miles traveled scoped by mode" do
        biker_ids = results.users_by_mileage.select {|res| res[:user].trips.first.mode == bike}.
          map {|res| res[:user].id}
        results.users_by_mileage(:mode => bike).map {|res| res[:user].id}.should == biker_ids
        walker_ids = results.users_by_mileage.select {|res| res[:user].trips.first.mode == walk}.
          map {|res| res[:user].id}
        results.users_by_mileage(:mode => walk).map {|res| res[:user].id}.should == walker_ids
      end

      it "should return the users in descending order of green miles traveled scoped by community" do
        #palo_alto_ids = results.users_by_mileage.select {|u| u.trips.first.mode == bike}.map(&:id)
        #results.user_by_mileage(:mode => bike).should == biker_ids
        #walker_ids = results.users_by_mileage.select {|u| u.trips.first.mode == walk}.map(&:id)
        #results.user_by_mileage(:mode => walk).should == walker_ids
      end
    end

    def fake_user_results(attr, *values)
      (0..(values.length - 1)).map do |index|
        {:id => index, attr => values[index]}
      end
    end

    describe "#users_by_green_trips" do
      before do
        mock(@results).user_results do
          fake_user_results(:total_green_trips, 5, 3, 1, 6, 7)
        end
      end

      it "should return users in descending order of number of green trips taken" do
        @results.users_by_green_trips.map {|res| res[:id]}.should == [4, 3, 0, 1, 2]
      end
    end

    describe "#filter_by_community(community)" do
      it "should filter by community" do
        mock(@results).user_results do 
          fake_user_results(:community_name, "Palo Alto", "Sunnyvale", "Mountain View", "Sunnyvale")
        end
        @results.filter_by_community(sunnyvale).size.should == 2
      end
    end

    describe "#sort_by_green_trips(results)" do

    end
    describe "#green_trips_for(community)" do
      it "should return users in descending order of number of green trips taken for specified community"
    end

    describe "#green_shopping_trips" do
      it "should return users in descending order of number of green shopping trips taken"
    end

    describe "#green_shopping_trips_for(community)" do
      it "should return users in descending order of number of green shopping trips taken for specified community"
    end

    describe "#greenest_travel" do
      it "should return users by least CO2 emissions per mile"
    end

    describe "#greenest_travel_for(community)" do 
      it "should return users by least CO2 emissions per mile for specified community"
    end

    describe "#most_improved_over_baseline" do
      it "should return users with the greatest increase in percent of green miles over baseline"
    end

    describe "#most_improved_over_baseline_for(community)" do
      it "should return users with the greatest increase in percent of green miles over baseline for specified community"
    end

    describe "#largest_groups" do
      it "should return the group with the largest number of members who logged 5 or more days" do
      end
    end

    describe "#largest_groups_for(community)" do
      it "should return the group with the largest number of members who logged 5 or more days in community" do
      end
    end

    describe "#greenest_groups_of_type(destination)" do
      it "should return greenest groups of type destination"
    end

    describe "generate_csv" do
      it "should generate a csv containing all prizes"
    end
  end
end