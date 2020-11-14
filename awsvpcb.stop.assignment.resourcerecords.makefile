# Make delete resource records file from existing records
#
sed '$d' $1 > $1.temp 
sed '$d' $1.temp > $1 
echo "{"                            > $AWSCLI_HOME/secfiles/route53-delete.json
echo "  \"Changes\": ["            >> $AWSCLI_HOME/secfiles/route53-delete.json
echo "    {"                       >> $AWSCLI_HOME/secfiles/route53-delete.json
echo "  \"Action\": \"DELETE\","   >> $AWSCLI_HOME/secfiles/route53-delete.json
echo "  \"ResourceRecordSet\": "   >> $AWSCLI_HOME/secfiles/route53-delete.json
input="$1"
counter=0
while IFS= read -r line
do
  let counter=counter+1
  if [ $counter -le 31 ];then
     continue
  fi
  if [[ $line == *"},"* ]]; then
     echo "    }"                       >> $AWSCLI_HOME/secfiles/route53-delete.json
     echo "    },"                      >> $AWSCLI_HOME/secfiles/route53-delete.json
     echo "    {"                       >> $AWSCLI_HOME/secfiles/route53-delete.json
     echo "  \"Action\": \"DELETE\","   >> $AWSCLI_HOME/secfiles/route53-delete.json
     echo "  \"ResourceRecordSet\": "   >> $AWSCLI_HOME/secfiles/route53-delete.json
     continue 
  fi
  echo "$line"                          >> $AWSCLI_HOME/secfiles/route53-delete.json
done < "$input"
echo "}]}"                              >> $AWSCLI_HOME/secfiles/route53-delete.json

