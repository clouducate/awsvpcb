# Make create resource records file from existing records for NEXT START of assignment
#
if [ -f $AWSCLI_HOME/secfiles/route53-create.json.temp ]; then
   rm $AWSCLI_HOME/secfiles/route53-create.json.temp
fi
touch $AWSCLI_HOME/secfiles/route53-create.json.temp
echo "{"                            > $AWSCLI_HOME/secfiles/route53-create.json
echo "  \"Changes\": ["            >> $AWSCLI_HOME/secfiles/route53-create.json
echo "    {"                       >> $AWSCLI_HOME/secfiles/route53-create.json
echo "  \"Action\": \"CREATE\","   >> $AWSCLI_HOME/secfiles/route53-create.json
echo "  \"ResourceRecordSet\": "   >> $AWSCLI_HOME/secfiles/route53-create.json
input="$1"
counter=0
while IFS= read -r line
do
  let counter=counter+1
  if [ $counter -le 31 ];then
     continue
  fi
  if [[ $line == *"},"* ]]; then
     cat $AWSCLI_HOME/secfiles/route53-create.json.temp >> $AWSCLI_HOME/secfiles/route53-create.json
     echo "    }"                       >  $AWSCLI_HOME/secfiles/route53-create.json.temp
     echo "    },"                      >> $AWSCLI_HOME/secfiles/route53-create.json.temp
     echo "    {"                       >> $AWSCLI_HOME/secfiles/route53-create.json.temp
     echo "  \"Action\": \"CREATE\","   >> $AWSCLI_HOME/secfiles/route53-create.json.temp
     echo "  \"ResourceRecordSet\": "   >> $AWSCLI_HOME/secfiles/route53-create.json.temp
     continue 
  fi
  echo "$line"                          >> $AWSCLI_HOME/secfiles/route53-create.json.temp
done < "$input"

cat $AWSCLI_HOME/secfiles/route53-create.json.temp >> $AWSCLI_HOME/secfiles/route53-create.json
echo "}]}"                              >> $AWSCLI_HOME/secfiles/route53-create.json

