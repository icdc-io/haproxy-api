RSpec.describe Backend, type: :model do

  context 'assotiations' do
    it { is_expected.to embed_many(:servers) }
  end


end