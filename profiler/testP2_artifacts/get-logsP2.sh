#!/bin/bash

list_urls=250m_test_urls.txt
output_prefix=log-static-jpeg-250m-2-B
group_name=${1:-gitc-fy2-oe2-onearth}

mkdir $output_prefix
i="0"
reps="10"
while [ $i -lt $reps ]
do
output_prefix_i=$output_prefix$i
echo $output_prefix_i
start_time=$(( ( $(date -u +"%s") - 1 ) * 1000 ))
echo "start" $start_time
echo $list_urls"_"$i
siege -f $list_urls"_"$i -r 100 -c 100 > $output_prefix_i.siege.txt
#siege -f $list_urls"_"$i -r 100 -c 50 > $output_prefix_i.siege.txt
sleep 80
end_time=$(( ( $(date -u +"%s") ) * 1000 ))
echo "end" $end_time
aws logs filter-log-events --log-group-name "$group_name" --filter-pattern "begin_onearth_handle" --start-time $start_time > $output_prefix/$output_prefix_i-begin_onearth.json
aws logs filter-log-events --log-group-name "$group_name" --filter-pattern "end_onearth_handle" --start-time $start_time > $output_prefix/$output_prefix_i-end_onearth.json
aws logs filter-log-events --log-group-name "$group_name" --filter-pattern "begin_mod_mrf_handle" --start-time $start_time > $output_prefix/$output_prefix_i-begin_mod_mrf.json
aws logs filter-log-events --log-group-name "$group_name" --filter-pattern "end_mod_mrf_handle" --start-time $start_time > $output_prefix/$output_prefix_i-end_mod_mrf.json
aws logs filter-log-events --log-group-name "$group_name" --filter-pattern "begin_send_to_date_service" --start-time $start_time > $output_prefix/$output_prefix_i-begin_send_to_date_service.json
aws logs filter-log-events --log-group-name "$group_name" --filter-pattern "end_send_to_date_service" --start-time $start_time > $output_prefix/$output_prefix_i-end_send_to_date_service.json
aws logs filter-log-events --log-group-name "$group_name" --filter-pattern "mod_mrf_s3_read" --start-time $start_time > $output_prefix/$output_prefix_i-s3.json
aws logs filter-log-events --log-group-name "$group_name" --filter-pattern "mod_mrf_index_read" --start-time $start_time > $output_prefix/$output_prefix_i-idx.json
i=$[$i+1]
sleep 10
done

python ../cat_event_logs.py $output_prefix $output_prefix.json