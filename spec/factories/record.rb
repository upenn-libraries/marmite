FactoryBot.define do
  factory :record do
    trait :marc21 do
      bib_id { 'sample_bib' }
      format { 'marc21' }
    end

    trait :iiif_presentation do
      bib_id { 'test-record' }
      format { 'iiif_presentation' }
      blob { BlobHandler.compress('test-record-blob') }
    end

    trait :structural do
      bib_id { 'test-record' }
      format { 'structural' }
      blob   { BlobHandler.compress('test-record-blob') }
    end
  end
end