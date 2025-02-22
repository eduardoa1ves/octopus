require "spec_helper"

describe Octopus::Model do
  describe "#using method" do
    it "should return self after calling the #using method" do
      User.using(:canada).should be_a(Octopus::ScopeProxy)
    end

    it "should allow to send a block to the master shard" do
      Octopus.using(:master) do
        User.create!(:name => "Block test")
      end

      User.using(:master).find_by_name("Block test").should_not be_nil
    end

    it 'should allow to pass a string as the shard name to a AR subclass' do
      User.using('canada').create!(:name => 'Rafael Pilha')

      User.using('canada').find_by_name('Rafael Pilha').should_not be_nil
    end

    it 'should allow to pass a string as the shard name to a block' do
      Octopus.using('canada') do
        User.create!(:name => 'Rafael Pilha')
      end

      User.using('canada').find_by_name('Rafael Pilha').should_not be_nil
    end

    it "should allow selecting the shards on scope" do
      User.using(:canada).create!(:name => 'oi')
      User.using(:canada).count.should == 1
      User.count.should == 0
    end

    it "should allow selecting the shard using #new" do
      u = User.using(:canada).new
      u.name = "Thiago"
      u.save

      User.using(:canada).count.should == 1
      User.using(:brazil).count.should == 0

      u1 = User.new
      u1.name = "Joaquim"
      u2 = User.using(:canada).new
      u2.name = "Manuel"
      u1.save()
      u2.save()

      User.using(:canada).all.should == [u, u2]
      User.all.should == [u1]
    end

    describe "multiple calls to the same scope" do
      it "works with nil response" do
        scope = User.using(:canada)
        scope.count.should == 0
        scope.first.should be_nil
      end

      it "works with non-nil response" do
        user = User.using(:canada).create!(:name => 'oi')
        scope = User.using(:canada)
        scope.count.should == 1
        scope.first.should == user
      end
    end

    it "should select the correct shard" do
      User.using(:canada)
      User.create!(:name => 'oi')
      User.count.should == 1
    end

    it "should ensure that the connection will be cleaned" do
      ActiveRecord::Base.connection.current_shard.should == :master
      begin
        Octopus.using(:canada) do
          raise "Some Exception"
        end
      rescue
      end

      ActiveRecord::Base.connection.current_shard.should == :master
    end

    it "should allow creating more than one user" do
      User.using(:canada).create([{ :name => 'America User 1' }, { :name => 'America User 2' }])
      User.create!(:name => "Thiago")
      User.using(:canada).find_by_name("America User 1").should_not be_nil
      User.using(:canada).find_by_name("America User 2").should_not be_nil
      User.using(:master).find_by_name("Thiago").should_not be_nil
    end

    it "should work when you have a SQLite3 shard" do
      u = User.using(:sqlite_shard).create!(:name => "Sqlite3")
      User.using(:sqlite_shard).find_by_name("Sqlite3").should == u
    end

    it "should clean #current_shard from proxy when using execute" do
      User.using(:canada).connection().execute("select * from users limit 1;")
      User.connection.current_shard.should == :master
    end

    it "should allow scoping dynamically" do
      User.using(:canada).using(:master).using(:canada).create!(:name => 'oi')
      User.using(:canada).using(:master).count.should == 0
      User.using(:master).using(:canada).count.should == 1
    end

    it "should allow find inside blocks" do
      @user = User.using(:brazil).create!(:name => "Thiago")

      Octopus.using(:brazil) do
        User.first.should == @user
      end

      User.using(:brazil).find_by_name("Thiago").should == @user
    end

    it "should clean the current_shard after executing the current query" do
      User.using(:canada).create!(:name => "oi")
      User.count.should == 0
    end

    it "should support both groups and alone shards" do
      u = User.using(:alone_shard).create!(:name => "Alone")
      User.using(:alone_shard).count.should == 1
      User.using(:canada).count.should == 0
      User.using(:brazil).count.should == 0
      User.count.should == 0
    end

    it "should work with named scopes" do
      u = User.using(:brazil).create!(:name => "Thiago")

      User.thiago.using(:brazil).first.should eq(u)
      User.using(:brazil).thiago.first.should eq(u)

      Octopus.using(:brazil) do
        User.thiago.first.should eq(u)
      end
    end

    describe "#current_shard attribute" do
      it "should store the attribute when you create or find an object" do
        u = User.using(:alone_shard).create!(:name => "Alone")
        u.current_shard.should == :alone_shard
        User.using(:canada).create!(:name => 'oi')
        u = User.using(:canada).find_by_name("oi")
        u.current_shard.should == :canada
      end

      it "should store the attribute when you find multiple instances" do
        5.times { User.using(:alone_shard).create!(:name => "Alone") }

        User.using(:alone_shard).all.each do |u|
          u.current_shard.should == :alone_shard
        end
      end

      it "should works when you find, and after that, alter that object" do
        alone_user = User.using(:alone_shard).create!(:name => "Alone")
        master_user = User.using(:master).create!(:name => "Master")
        alone_user.name = "teste"
        alone_user.save
        User.using(:master).find(:first).name.should == "Master"
        User.using(:alone_shard).find(:first).name.should == "teste"
      end

      it "should work for the reload method" do
        User.using(:alone_shard).create!(:name => "Alone")
        u = User.using(:alone_shard).find_by_name("Alone")
        u.reload
        u.name.should == "Alone"
      end

      it "should work passing some arguments to reload method" do
        User.using(:alone_shard).create!(:name => "Alone")
        u = User.using(:alone_shard).find_by_name("Alone")
        u.reload(:lock => true)
        u.name.should == "Alone"
      end
    end

    describe "passing a block" do
      it "should allow queries be executed inside the block, ponting to a specific shard" do
        Octopus.using(:canada) do
          User.create(:name => "oi")
        end

        User.using(:canada).count.should == 1
        User.using(:master).count.should == 0
        User.count.should == 0
      end

      it "should allow execute queries inside a model" do
        u = User.new
        u.awesome_queries()
        User.using(:canada).count.should == 1
        User.count.should == 0
      end
    end

    describe "raising errors" do
      it "should raise a error when you specify a shard that doesn't exist" do
        lambda { User.using(:crazy_shard).create!(:name => 'Thiago') }.should raise_error("Nonexistent Shard Name: crazy_shard")
      end
    end

    describe "equality" do
      let(:canada1) do
        u = User.new
        u.id = 1
        u.current_shard = :canada
        u
      end

      let(:canada1_dup) do
        u = User.new
        u.id = 1
        u.current_shard = :canada
        u
      end

      let(:brazil1) do
        u = User.new
        u.id = 1
        u.current_shard = :brazil
        u
      end

      it "should work with persisted objects" do
        u = User.using(:brazil).create(:name => "Mike")
        User.using(:brazil).find_by_name("Mike").should == u
      end

      if Octopus.rails31? || Octopus.rails32?
        # Rails <= 3.0 doesn't support equality checks on non-persisted objects
        it "should check current_shard when determining equality" do
          canada1.should_not == brazil1
          canada1.should == canada1_dup
        end

        it "delegates equality check on scopes" do
          u = User.using(:brazil).create!(:name => "Mike")
          User.using(:brazil).where(:name => "Mike").should == [u]
        end
      end
    end
  end

  describe "using a postgresql shard" do
    it "should update the Arel Engine" do
      if ActiveRecord::VERSION::STRING > '2.4.0'
        User.using(:postgresql_shard).arel_engine.connection.adapter_name.should == "PostgreSQL"
        User.using(:alone_shard).arel_engine.connection.adapter_name.should == "MySQL"
      end
    end

    it "should works with writes and reads" do
      u = User.using(:postgresql_shard).create!(:name => "PostgreSQL User")
      User.using(:postgresql_shard).find(:all).should == [u]
      User.using(:alone_shard).find(:all).should == []
      User.connection_handler.connection_pools["ActiveRecord::Base"] = User.connection.instance_variable_get(:@shards)[:master]
    end
  end

  describe "AR basic methods" do
    it "establish_connection" do
      CustomConnection.connection.current_database.should == "octopus_shard_2"
    end

    it "should not mess with custom connection table names" do
      Advert.connection.current_database.should == "octopus_shard_1"
      Advert.create!(:name => "Teste")
    end

    it "increment" do
      u = User.using(:brazil).create!(:name => "Teste", :number => 10)
      u = User.using(:brazil).find_by_number(10)
      u.increment(:number)
      u.save()
      u = User.using(:brazil).find_by_number(11).should_not be_nil
    end

    it "increment!" do
      u = User.using(:brazil).create!(:name => "Teste", :number => 10)
      u = User.using(:brazil).find_by_number(10)
      u.increment!(:number)
      u = User.using(:brazil).find_by_number(11).should_not be_nil
    end

    it "decrement" do
      u = User.using(:brazil).create!(:name => "Teste", :number => 10)
      u = User.using(:brazil).find_by_number(10)
      u.decrement(:number)
      u.save()
      u = User.using(:brazil).find_by_number(9).should_not be_nil
    end

    it "decrement!" do
      u = User.using(:brazil).create!(:name => "Teste", :number => 10)
      u = User.using(:brazil).find_by_number(10)
      u.decrement!(:number)
      u = User.using(:brazil).find_by_number(9).should_not be_nil
    end

    it "toggle" do
      u = User.using(:brazil).create!(:name => "Teste", :admin => false)
      u = User.using(:brazil).find_by_name('Teste')
      u.toggle(:admin)
      u.save()
      u = User.using(:brazil).find_by_name('Teste').admin.should be_true
    end

    it "toggle!" do
      u = User.using(:brazil).create!(:name => "Teste", :admin => false)
      u = User.using(:brazil).find_by_name('Teste')
      u.toggle!(:admin)
      u = User.using(:brazil).find_by_name('Teste').admin.should be_true
    end

    it "count" do
      u = User.using(:brazil).create!(:name => "User1")
      u2 = User.using(:brazil).create!(:name => "User2")
      u3 = User.using(:brazil).create!(:name => "User3")
      User.using(:brazil).find(:all, :conditions => {:name => "User2"}).count.should == 1
    end

    it "maximum" do
      u1 = User.using(:brazil).create!(:name => "Teste", :number => 11)
      u2 = User.using(:master).create!(:name => "Teste", :number => 12)

      User.using(:brazil).maximum(:number).should == 11
      User.using(:master).maximum(:number).should == 12
    end

    if Octopus.rails3?
      describe "any?" do
        before { User.using(:brazil).create!(:name => "User1") }

        it "works when true" do
          scope = User.using(:brazil).where(:name => "User1")
          scope.any?.should be_true
        end

        it "works when false" do
          scope = User.using(:brazil).where(:name => "User2")
          scope.any?.should be_false
        end
      end

      it "exists?" do
        @user = User.using(:brazil).create!(:name => "User1")

        User.using(:brazil).where(:name => "User1").exists?.should be_true
        User.using(:brazil).where(:name => "User2").exists?.should be_false
      end

      describe "touch" do
        it "updates updated_at by default" do
          @user = User.using(:brazil).create!(:name => "User1")
          User.using(:brazil).update_all({:updated_at => Time.now - 3.months}, {:id => @user.id})
          @user.touch
          @user.reload.updated_at.to_date.should eq(Date.today)
        end

        it "updates passed in attribute name" do
          @user = User.using(:brazil).create!(:name => "User1")
          User.using(:brazil).update_all({:created_at => Time.now - 3.months}, {:id => @user.id})
          @user.touch(:created_at)
          @user.reload.created_at.to_date.should eq(Date.today)
        end
      end

    end

    if Octopus.rails32?
      describe "#pluck" do
        before { User.using(:brazil).create!(:name => "User1") }

        it "should works from scope proxy" do
          names = User.using(:brazil).pluck(:name)
          names.should eq(["User1"])
          User.using(:master).pluck(:name).should eq([])
        end
      end

      it "update_column" do
        @user = User.using(:brazil).create!(:name => "User1")
        @user2 = User.using(:brazil).find(@user.id)
        @user2.update_column(:name, "Joaquim Shard Brazil")
        User.using(:brazil).find_by_name("Joaquim Shard Brazil").should_not be_nil
      end
    end

    it "update_attributes" do
      @user = User.using(:brazil).create!(:name => "User1")
      @user2 = User.using(:brazil).find(@user.id)
      @user2.update_attributes(:name => "Joaquim")
      User.using(:brazil).find_by_name("Joaquim").should_not be_nil
    end

    it "using update_attributes inside a block" do
      Octopus.using(:brazil) do
        @user = User.create!(:name => "User1")
        @user2 = User.find(@user.id)
        @user2.update_attributes(:name => "Joaquim")
      end

      User.find_by_name("Joaquim").should be_nil
      User.using(:brazil).find_by_name("Joaquim").should_not be_nil
    end

    it "update_attribute" do
      @user = User.using(:brazil).create!(:name => "User1")
      @user2 = User.using(:brazil).find(@user.id)
      @user2.update_attribute(:name, "Joaquim")
      User.using(:brazil).find_by_name("Joaquim").should_not be_nil
    end

    it "transaction" do
      u = User.create!(:name => "Thiago")

      User.using(:brazil).count.should == 0
      User.using(:master).count.should == 1

      User.using(:brazil).transaction do
        User.find_by_name("Thiago").should be_nil
        User.create!(:name => "Brazil")
      end

      User.using(:brazil).count.should == 1
      User.using(:master).count.should == 1
    end

    describe "deleting a record" do
      before(:each) do
        @user = User.using(:brazil).create!(:name => "User1")
        @user2 = User.using(:brazil).find(@user.id)
      end

      it "delete" do
        @user2.delete
        lambda { User.using(:brazil).find(@user2.id) }.should raise_error(ActiveRecord::RecordNotFound)
      end

      it "delete within block shouldn't lose shard" do
        Octopus.using(:brazil) do
          @user2.delete
          @user3 = User.create(:name => "User3")

          User.connection.current_shard.should == :brazil
          User.find(@user3.id).should == @user3
        end
      end

      it "destroy" do
        @user2.destroy
        lambda { User.using(:brazil).find(@user2.id) }.should raise_error(ActiveRecord::RecordNotFound)
      end

      it "destroy within block shouldn't lose shard" do
        Octopus.using(:brazil) do
          @user2.destroy
          @user3 = User.create(:name => "User3")

          User.connection.current_shard.should == :brazil
          User.find(@user3.id).should == @user3
        end
      end
    end
  end

  describe "when using set_table_name" do
    it 'should work correctly' do
      Bacon.using(:brazil).create!(:name => "YUMMMYYYY")
    end

    it 'should work correctly with a block' do
      Cheese.using(:brazil).create!(:name => "YUMMMYYYY")
    end
  end

  if Octopus.rails32?
    describe "when using table_name=" do
      it 'should work correctly' do
        Ham.using(:brazil).create!(:name => "YUMMMYYYY")
      end
    end
  end

  describe "when using a environment with a single adapter" do
    it 'should not clean the table name' do
      OctopusHelper.using_environment :production_fully_replicated do
        Keyboard.should_not_receive(:reset_table_name)
        Keyboard.using(:master).create!(:name => "Master Cat")
      end
    end
  end

  describe "when you have joins/include" do
    before(:each) do
      @client1 = Client.using(:brazil).create(:name => "Thiago")

      Octopus.using(:canada) do
        @client2 = Client.create(:name => "Mike")
        @client3 = Client.create(:name => "Joao")
        @item1 = Item.create(:client => @client2, :name => "Item 1")
        @item2 = Item.create(:client => @client2, :name => "Item 2")
        @item3 = Item.create(:client => @client3, :name => "Item 3")
        @part1 = Part.create(:item => @item1, :name => "Part 1")
        @part2 = Part.create(:item => @item1, :name => "Part 2")
        @part3 = Part.create(:item => @item2, :name => "Part 3")
      end

      @item4 = Item.using(:brazil).create(:client => @client1, :name => "Item 4")
    end

    it "should work with the rails 2.x syntax" do
      items = Item.using(:canada).find(:all, :joins => :client, :conditions => { :clients => { :id => @client2.id } })
      items.should == [@item1, @item2]
    end

    it "should work using the rails 3.x syntax" do
      if Octopus.rails3?
        items = Item.using(:canada).joins(:client).where("clients.id = #{@client2.id}").all
        items.should == [@item1, @item2]
      end
    end

    it "should work for include also, rails 2.x syntax" do
      items = Item.using(:canada).find(:all, :include => :client, :conditions => { :clients => { :id => @client2.id } })
      items.should == [@item1, @item2]
    end

    it "should work for include also, rails 3.x syntax" do
      if Octopus.rails3?
        items = Item.using(:canada).includes(:client).where("clients.id = #{@client2.id}").all
        items.should == [@item1, @item2]
      end
    end

    it "should work for multiple includes, with rails 2.x syntax" do
      parts = Part.using(:canada).find(:all, :include => {:item => :client}, :conditions => {:clients => { :id => @client2.id}})
      parts.should == [@part1, @part2, @part3]
      parts.first.item.client.should == @client2
    end

    it "should work for multiple join, with rails 2.x syntax" do
      parts = Part.using(:canada).find(:all, :joins => {:item => :client}, :conditions => {:clients => { :id => @client2.id}})
      parts.should == [@part1, @part2, @part3]
      parts.first.item.client.should == @client2
    end
  end

  describe "ActiveRecord::Base Validations" do
    it "should work correctly when using validations" do
      @key = Keyboard.create!(:name => "Key")
      lambda { Keyboard.using(:brazil).create!(:name => "Key") }.should_not raise_error()
      lambda { Keyboard.create!(:name => "Key") }.should raise_error()
    end

    it "should work correctly when using validations with using syntax" do
      @key = Keyboard.using(:brazil).create!(:name => "Key")
      lambda { Keyboard.create!(:name => "Key") }.should_not raise_error()
      lambda { Keyboard.using(:brazil).create!(:name => "Key") }.should raise_error()
    end
  end

  describe "#replicated_model method" do
    it "should be replicated" do
      OctopusHelper.using_environment :production_replicated do
        ActiveRecord::Base.connection_proxy.instance_variable_get(:@replicated).should be_true
      end
    end

    it "should mark the Cat model as replicated" do
      OctopusHelper.using_environment :production_replicated do
        User.replicated.should be_false
        Cat.replicated.should be_true
      end
    end
  end
end
