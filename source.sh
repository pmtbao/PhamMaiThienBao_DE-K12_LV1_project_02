#!/bin/bash
# xlsx to csv
libreoffice --headless --convert-to csv products-0-200000.xlsx

# URL cua API
API_URL="https://api.tiki.vn/product-detail/api/v1/products"

# tap tin chua cac ID
ID_FILE="products-0-200000.csv"

# thu muc tam luu du lieu json
TEMP_DIR="temp_data"
mkdir -p $TEMP_DIR

# func chuan hoa noi dung trong "description"
normalize_description(){
  local description=$1
  # loai bo cac tag HTML
  clean_description=$(echo "$description" | sed 's/<[^>]*>//g')
  # loai bo khoang trang thua
  clean_description=$(echo "$clean_description" | tr -s ' ')
}

# func lay data cua mot id va lua vao file json
fetch_data() {
  local id=$1
  response=$(curl -s "${API_URL}/${id}")
  if [[ $(echo "$response" | jq -r '.id') != "null" ]]; then
    id=$(echo "$response" | jq -r '.id')
    name=$(echo "$response" | jq -r '.name')
    url_key=$(echo "$response" | jq -r '.url_key')
    price=$(echo "$response" | jq -r '.price')
    description=$(echo "$response" | jq -r '.description')
    description=$(normalize_description "$description")
    images=$(echo "$response" | jq -r '.images')

    # tao json object
    json_data=$(jq -n \
      --arg id "$id" \
      --arg name "$name" \
      --arg url_key "$url_key" \
      --arg price "$price" \
      --arg description "$description" \
      --arg images "$images" \
      '{id: $id, name: $name, url_key: $url_key, price: $price, description: $description, images: $images}')

    echo "$json_data" > "${TEMP_DIR}/data_${id}.json"
  else
    echo "Failed to fetch data for ID: $id"
    echo "$id" >> fail.txt
  fi
}

# doc tap tin chua id va request API song song
while read id; do
fetch_data $id &
done < <(tail -n +2 "$ID_FILE")

# cho cac yeu cau hoan thanh
wait

# nhap data vào MongoDB
for file in ${TEMP_DIR}/*json; do
mongoimport --db dec-k12-project02 --collection products --type json --file $file
done

# xoa temp dir
# rm -r $TEMP_DIR

echo "Hoan thanh viec lay data va luu vao MongoDB"
