require "administrate/field/base"

class GithubPushEventSummaryField < Administrate::Field::Base
  def push_event
    data
  end

  def to_s
    push_event.github_event_id
  end
end
