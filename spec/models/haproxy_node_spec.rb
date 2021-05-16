RSpec.describe HaproxyNode, type: :model do

  context 'assotiations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:host) }
  end


end