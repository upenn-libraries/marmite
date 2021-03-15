module FixtureHelpers
  def marc21_post_transform(bib_id)
    File.read(File.join('spec',
                        'fixtures',
                        'post_transformation',
                        'marc21',
                        "#{bib_id}.xml"))
  end

  def marc21_pre_transform(bib_id)
    File.read(File.join('spec',
                        'fixtures',
                        'pre_transformation',
                        'marc',
                        "#{bib_id}.xml"))
  end

  def marc21_pre_transform_updated(bib_id)
    File.read(File.join('spec',
                        'fixtures',
                        'pre_transformation',
                        'marc',
                        "#{bib_id}.xml"))
        .sub("Aristotle's De interpretatione", "Plato's The Republic") # hehe
  end
end
