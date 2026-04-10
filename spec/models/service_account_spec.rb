# frozen_string_literal: true

RSpec.describe ServiceAccount, type: :model do
  describe '#as_payload' do
    let!(:_permission_member) { create(:permission, role: 'member') }
    let!(:_permission_sa) { create(:permission, role: 'service_account') }
    let(:owner) { create(:user) }
    let(:service_account) { create(:service_account, user: owner) }

    subject(:payload) { service_account.as_payload }

    it 'sets uid to the owner user uid' do
      expect(payload['uid']).to eq(owner.uid)
    end

    it 'sets sid to the service account uid' do
      expect(payload['sid']).to eq(service_account.uid)
    end

    it 'includes email, role, level and state from the service account' do
      expect(payload['email']).to eq(service_account.email)
      expect(payload['role']).to eq(service_account.role)
      expect(payload['level']).to eq(service_account.level)
      expect(payload['state']).to eq(service_account.state)
    end

    it 'does not expose the service account uid as uid' do
      expect(payload['uid']).not_to eq(service_account.uid)
    end
  end
end
