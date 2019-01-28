module RcprefsHelper
  def show_comments decorator
    decorator.collector_pointers.collect { |rr|
      if rr.comment.present?
        render "collectible/show_comment", rcpref: rr
      end
    }.compact.join.html_safe
  end
end