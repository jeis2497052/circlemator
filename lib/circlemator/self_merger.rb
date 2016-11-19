# frozen_string_literal: true
require 'httparty'
require 'json'

module Circlemator
  class SelfMerger
    DEFAULT_MESSAGE = 'Auto-merge by Circlemator!'

    def initialize(opts)
      github_repo = opts.fetch(:github_repo)
      raise "#{github_repo} is invalid" unless github_repo.is_a? GithubRepo

      @github_repo = github_repo
      @sha = opts.fetch(:sha)
      @opts = opts
    end

    def merge!
      @pr_number, @pr_url = PrFinder.new(@opts).find_pr
      return if @pr_number.nil? || @pr_url.nil?

      response = @github_repo.put "#{@pr_url}/merge",
                                  body: { commit_message: commit_message, sha: @sha }.to_json
      if response.code != 200
        body = JSON.parse(response.body)
        raise "Merge failed: #{body.fetch('message')}"
      end
    end

    private

    def commit_message
      jira_project = @opts[:jira_project]
      jira_transition = @opts[:jira_transition]

      if jira_project && jira_transition
        jira_commit_message(jira_project, jira_transition)
      else
        DEFAULT_MESSAGE
      end
    end

    def jira_commit_message(jira_project, jira_transition)
      resp = @github_repo.get "#{@pr_url}/commits"
      raise "Github API response error: #{resp}" unless resp.code == 200
      commits = JSON.parse(resp.body)

      tag_re = /#{jira_project}-\d+/
      issues = commits.flat_map do |commit|
        commit.fetch('commit').fetch('message').scan tag_re
      end

      issues.to_set.sort.map { |issue| "#{issue} ##{jira_transition}"}.join("\n")
    end
  end
end
