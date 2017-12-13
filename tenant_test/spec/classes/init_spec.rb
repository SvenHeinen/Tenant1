require 'spec_helper'
describe 'check_mk_ws2016' do
  context 'with default values for all parameters' do
    it { should contain_class('check_mk_ws2016') }
  end
end
