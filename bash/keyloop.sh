for i in {1..100}; do
  curl -i http://$KONG/hello -H "apikey: super-secret-key"
  echo ""
done