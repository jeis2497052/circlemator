# frozen_string_literal: true
require 'circlemator/self_merger'
require 'circlemator/github_repo'
require 'circlemator/pr_finder'

RSpec.describe Circlemator::SelfMerger do
  describe '#merge!' do
    let(:default_opts) do
      {
        sha: '1234567',
        base_branch: 'master',
        compare_branch: 'topic',
      }
    end
    let(:opts) { default_opts }

    let(:github_repo) do
      Circlemator::GithubRepo.new user: 'rainforestapp',
                                  repo: 'circlemator',
                                  github_auth_token: 'abc123'
    end
    let(:merger) { described_class.new github_repo: github_repo, **opts }

    let(:pr_url) { 'https://api.github.com/rainforestapp/circlemator/pulls/12345' }

    before do
      allow_any_instance_of(Circlemator::PrFinder)
        .to receive(:find_pr)
             .and_return [12345, pr_url]
    end

    it 'merges the pull request' do
      expect(github_repo)
        .to receive(:put).with("#{pr_url}/merge",
                               body: { commit_message: described_class::DEFAULT_MESSAGE, sha: '1234567' }.to_json)
             .and_return double(code: 200)

      merger.merge!
    end

    context 'when JIRA options are set' do
      let(:commit_response) do
        [
          {
            'commit' => {
              'message' => 'CM-123 foobar',
            },
          },
          {
            'commit' => {
              'message' => "CM-123 baz\nCM-277",
            },
          },
          {
            'commit' => {
              'message' => 'CM-246 abc',
            },
          },
        ]
      end

      let(:opts) { default_opts.merge(jira_project: 'CM', jira_transition: 'ship') }

      before do
        allow(github_repo)
          .to receive(:get).with("#{pr_url}/commits")
                .and_return double(code: 200, body: commit_response.to_json)
      end

      let(:expected_commit_message) { "CM-123 #ship\nCM-246 #ship\nCM-277 #ship" }

      it 'adds jira transitions for all commits in the body' do
        expect(github_repo)
          .to receive(:put).with("#{pr_url}/merge",
                                 body: { commit_message: expected_commit_message, sha: '1234567' }.to_json)
                  .and_return double(code: 200)

        merger.merge!
      end
    end
  end
end
