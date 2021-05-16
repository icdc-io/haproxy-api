RSpec.describe Security, type: :model do

  context 'assotiations' do
    it { is_expected.to embed_one(:project) }
  end


end
