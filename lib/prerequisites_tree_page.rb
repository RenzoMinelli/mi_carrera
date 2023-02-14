class PrerequisitesTreePage < BedeliasPage
  def root_node
    find("//td[@data-rowkey='root']")
  end

  def back
    click_on 'Volver'
  end

  def extract_subjects_from(node_content)
    subjects = []
    _, *approvables = node_content.split(/(?=\b(?:Examen|Curso|U\.C\.B aprobada)\b)\s*/)

    approvables.each do |approvable|
      needs =
        if approvable.include?("U.C.B aprobada:")
          'all'
        elsif approvable.include?("Examen")
          'exam'
        elsif approvable.include?("Curso")
          'course'
        end

      subjects << {
        subject_needed_code: subject_code(approvable),
        subject_needed_name: subject_name(approvable),
        needs: needs,
      }
    end

    subjects
  end

  def only_one_approval_needed?(node)
    node.first("div/span[@class='negrita']").text.split(' ')[0] == '1'
  end

  def amount_of_subjects_needed(node)
    node.first("div/span[@class='negrita']").text.split(' ')[0].to_i
  end

  def needs_all_approvals?(node)
    amount_of_subjects_needed(node) == ammount_of_subjects_in_node_content(node_content_from_node(node))
  end

  def ammount_of_subjects_in_node_content(node_content)
    node_content.split('entre: ')[1]
                .enum_for(:scan, /(?=((Examen)|(Curso)|(U\.C\.B aprobada)))/)
                .count
  end

  def subject_code(node)
    node.match(/([\dA-Z]+ - )?([\dA-Z]+) -/)[2]
  end

  def subject_name(node)
    node.split('- ', 2).last.strip
  end

  def expand_prerequisites_tree(node)
    toggler = node.find("div/span[contains(@class, 'ui-tree-toggler')]")
    if toggler[:class].include?('plus')
      toggler.click
    end
  end

  def node_content_from_node(node)
    node.first('div').text
  end

  def credits_from_node(node)
    node_content_from_node(node).split(' créditos')[0].to_i
  end

  def group_from_node(node)
    node_content_from_node(node).split('Grupo: ')[1].to_i
  end

  def prerequisite_type(prerequisite_node)
    node_type = prerequisite_node['data-nodetype']
    node_content = node_content_from_node(prerequisite_node)

    case node_type
    when 'default'
      if node_content.include?('créditos en el Plan:')
        :credits
      elsif node_content.include?('aprobación') || node_content.include?('actividad')
        if only_one_approval_needed?(prerequisite_node)
          :any_subject_from_node
        elsif needs_all_approvals?(prerequisite_node)
          :all_subjects_from_node
        else # 'n' approvals needed out of a list of 'm' subjects when 'n'<'m'
          :n_subjects_from_node
        end
      elsif node_content.include?('Curso aprobado')
        :subject_course
      elsif node_content.include?('Examen aprobado')
        :subject_exam
      elsif node_content.include?('Aprobada')
        :subject_all
      elsif node_content.include?('Inscripción a Curso')
        :subject_enrollment
      end
    when 'cag' # 'créditos en el Grupo:'
      :credits_group
    when 'y'
      :logical_and_tree
    when 'no'
      :logical_not_tree
    when 'o'
      :logical_or_tree
    end
  end

  def prerequisite_tree(prerequisite_node)
    node_content = node_content_from_node(prerequisite_node)
    type = prerequisite_type(prerequisite_node)
    ret = {}

    case type
    when :credits
      ret[:type] = 'credits'
      ret[:credits] = credits_from_node(prerequisite_node)
    when :credits_group
      ret[:type] = 'credits'
      ret[:credits] = credits_from_node(prerequisite_node)
      ret[:group] = group_from_node(prerequisite_node)
    when :all_subjects_from_node
      ret[:type] = 'logical'
      ret[:logical_operator] = 'and'
      ret[:operands] =
        extract_subjects_from(node_content).each_with_object([]) do |s, array|
          array << {
            type: 'subject',
            subject_needed_code: s[:subject_needed_code],
            subject_needed_name: s[:subject_needed_name],
            needs: s[:needs]
          }
        end
    when :any_subject_from_node
      ret[:type] = 'logical'
      ret[:logical_operator] = 'or'
      ret[:operands] =
        extract_subjects_from(node_content).each_with_object([]) do |s, array|
          array << {
            type: 'subject',
            subject_needed_code: s[:subject_needed_code],
            subject_needed_name: s[:subject_needed_name],
            needs: s[:needs]
          }
        end
    when :n_subjects_from_node
      ret[:type] = 'logical'
      ret[:logical_operator] = 'at_least'
      ret[:amount_of_subjects_needed] = amount_of_subjects_needed(prerequisite_node)
      ret[:operands] =
        extract_subjects_from(node_content).each_with_object([]) do |s, array|
          array << {
            type: 'subject',
            subject_needed_code: s[:subject_needed_code],
            subject_needed_name: s[:subject_needed_name],
            needs: s[:needs]
          }
        end
    when :logical_and_tree
      ret = logical_prerequisite_branch_node_details(prerequisite_node, operator: 'and')
    when :logical_or_tree
      ret = logical_prerequisite_branch_node_details(prerequisite_node, operator: 'or')
    when :logical_not_tree
      ret = logical_prerequisite_branch_node_details(prerequisite_node, operator: 'not')
    when :subject_course
      ret = subject_prerequisite_node_details(prerequisite_node, variant: 'course')
    when :subject_exam
      ret = subject_prerequisite_node_details(prerequisite_node, variant: 'exam')
    when :subject_all
      ret = subject_prerequisite_node_details(prerequisite_node, variant: 'all')
    when :subject_enrollment
      ret = subject_prerequisite_node_details(prerequisite_node, variant: 'enrollment')
    end

    ret
  end

  def logical_prerequisite_branch_node_details(prerequisite_node, operator:)
    expand_prerequisites_tree(prerequisite_node)
    child_nodes = prerequisite_node.all(
      "following-sibling::td/div/table/tbody/tr/td[contains(@class, 'ui-treenode ')]",
      visible: false
    )
    operands =
      child_nodes.each_with_object([]) do |child_node, array|
        array << prerequisite_tree(child_node)
      end

    {
      type: 'logical',
      logical_operator: operator,
      operands: operands,
    }
  end

  def subject_prerequisite_node_details(prerequisite_node, variant:)
    {
      type: 'subject',
      needs: variant,
      subject_needed_code: subject_code(node_content_from_node(prerequisite_node)),
      subject_needed_name: subject_name(node_content_from_node(prerequisite_node)),
    }
  end
end
