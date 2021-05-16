RSpec.describe Cert, type: :model do

  context 'assotiations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:owner) }
    it { is_expected.to validate_presence_of(:cert) }

    it { is_expected.to validate_uniqueness_of(:filename) }
  end


end
