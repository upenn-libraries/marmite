FactoryBot.define do
  factory :record do
    factory :marc21_record do
      bib_id { '1234567' }
      format { 'marc21' }
    end

    factory :iiif_record do
      bib_id { '81431-abcdef' }
      format { 'iiif_presentation' }
      blob { BlobHandler.compress('test-record-blob') }
    end

    factory :structural_record do
      bib_id { '1234567' }
      format { 'structural' }
      blob   { BlobHandler.compress('test-record-blob') }

      trait :without_pages do
        bib_id { '9912345673503681' }
        blob { BlobHandler.compress(File.read('spec/fixtures/post_transformation/structural/empty.xml')) }
      end

      trait :with_pages do
        bib_id { '994952127' }
        blob { BlobHandler.compress(File.read('spec/fixtures/post_transformation/structural/9959683393503681.xml')) }
      end
    end
  end
end