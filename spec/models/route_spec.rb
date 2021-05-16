RSpec.describe Route, type: :model do

  context 'assotiations' do
    it { is_expected.to embed_one(:backend) }
    it { is_expected.to embed_one(:security) }
  end

end
