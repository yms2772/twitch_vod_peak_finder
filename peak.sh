#!/bin/bash
WHITE='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
LIGHT_PURPLE='\033[0;35m'
LIGHT_BLUE='\033[0;36m'
VOD_ID="$1"

function RESPONSE(){
if [ "$2" = red ]
then
printf "${RED}| $3 | $(date +%Y.%m.%d) ($(date +%H:%M:%S)) | $1${WHITE}\n"
elif [ "$2" = yellow ]
then
printf "${YELLOW}| $3 | $(date +%Y.%m.%d) ($(date +%H:%M:%S)) | $1${WHITE}\n"
elif [ "$2" = l_purple ]
then
printf "${LIGHT_PURPLE}| $3 | $(date +%Y.%m.%d) ($(date +%H:%M:%S)) | $1${WHITE}\n"
elif [ "$2" = l_blue ]
then
printf "${LIGHT_BLUE}| $3 | $(date +%Y.%m.%d) ($(date +%H:%M:%S)) | $1${WHITE}\n"
else
echo "| $3 | $(date +%Y.%m.%d) ($(date +%H:%M:%S)) | $1"
fi
}

function GO(){
RESPONSE "Caculating h:m:s to seconds..." l_blue "$BROADCAST_ID"
awk '{print $2}' cache/$VOD_ID/clips_info_total | tr 'hm' ' ' | sed 's/s//g' | while read i
do

case "$(echo $i | awk '{print NF}')" in
1 )
TIME_S="$(echo $i | awk '{print $1}')"

TIME=${TIME_S}
;;

2 )
TIME_M="$(expr $(echo $i | awk '{print $1}') \* 60)"
TIME_S="$(echo $i | awk '{print $2}')"

TIME=$(expr ${TIME_M} + ${TIME_S})
;;

3 )
TIME_H="$(expr $(echo $i | awk '{print $1}') \* 3600)"
TIME_M="$(expr $(echo $i | awk '{print $2}') \* 60)"
TIME_S="$(echo $i | awk '{print $3}')"

TIME=$(expr ${TIME_H} + ${TIME_M} + ${TIME_S})
;;
esac

echo "$TIME" | tr -d ' ' >> cache/$VOD_ID/clips_time_seconds
done

awk '{print $3}' cache/$VOD_ID/clips_info_total > cache/$VOD_ID/clips_view

# 누적도수
paste -d' ' cache/$VOD_ID/clips_time_seconds cache/$VOD_ID/clips_view | sort -n | awk '{print $1,(p+=$1)/NR}'  OFS='\t' | awk '!a[$1]++' > cache/$VOD_ID/clips_cal_cumulative

awk '{print $1}' cache/$VOD_ID/clips_cal_cumulative > cache/$VOD_ID/clips_cal_cumulative_time
awk '{print $2}' cache/$VOD_ID/clips_cal_cumulative > cache/$VOD_ID/clips_cal_cumulative_frequency

# 평균 변화율
paste -d' ' cache/$VOD_ID/clips_cal_cumulative_time cache/$VOD_ID/clips_cal_cumulative_frequency | awk '{if(NR>1)printf "%.1f\n",($2-b)/($1-a);a=$1;b=$2}' > cache/$VOD_ID/clips_cal_derivative

sed '1d' cache/$VOD_ID/clips_cal_cumulative_time > cache/$VOD_ID/clips_cal_cumulative_time_sed

paste -d' ' cache/$VOD_ID/clips_cal_cumulative_time_sed cache/$VOD_ID/clips_cal_derivative > cache/$VOD_ID/clips_plot

gnuplot -e "set terminal svg; set style data lines; plot 'cache/$VOD_ID/clips_plot' with lines lc rgb 'black'" > cache/$VOD_ID/result_plot.svg

LAST=$(cat cache/$VOD_ID/clips_plot | wc -l)
COUNT=1
cat cache/$VOD_ID/clips_plot | while read i
do
COUNT=$((COUNT+1))
RESPONSE "[$((COUNT-1))/$LAST] Caculating peak time..." l_blue "$BROADCAST_ID"

TIME_V="$(head -n $COUNT cache/$VOD_ID/clips_cal_cumulative_time_sed | tail -1)"

PRV="$(head -n $((COUNT-1)) cache/$VOD_ID/clips_cal_derivative | tail -1)"
NOW="$(head -n $COUNT cache/$VOD_ID/clips_cal_derivative | tail -1)"
NXT="$(head -n $((COUNT+1)) cache/$VOD_ID/clips_cal_derivative | tail -1)"

if [ "$(echo $NOW'>'$NXT | bc -l)" = 1 ] && [ "$(echo $NOW'>'$PRV | bc -l)" = 1 ]
then
echo "$TIME_V $NOW" >> cache/$VOD_ID/result
fi
done

gnuplot -e "set terminal svg; plot 'cache/$VOD_ID/result' lc rgb 'red'" > cache/$VOD_ID/result_dot.svg

gnuplot -e "set terminal svg; plot 'cache/$VOD_ID/clips_plot' with lines lc rgb 'black', 'cache/$VOD_ID/result' lc rgb 'red'" > cache/$VOD_ID/result_plus.svg

RESPONSE "* DONE !" l_purple "$BROADCAST_ID"

GET_JSON
exit 0
}

function GET_JSON(){
LAST_LINE="$(tail -1 cache/$VOD_ID/result)"
LAST_LINE_NO="$(awk '{print $2}' cache/$VOD_ID/result | sort -n | tail -1)"
P_TOTAL="$(cat cache/$VOD_ID/result | wc -l)"
P_COUNT=0

cat << EOF > cache/$VOD_ID/result_${VOD_ID}.json_old
{
"result": "success",
"total": "$P_TOTAL",
"vod_duration": "$BROADCAST_DURATION",
"vod_duration_sec": "$BROADCAST_DURATION_SEC",
"data": [
EOF

cat cache/$VOD_ID/result | while read i
do
P_COUNT=$((P_COUNT+1))

VOD_TIME="$(echo $i | awk '{print $1}')"
VOD_DE="$(echo $i | awk '{print $2}')"

VOD_DE_NORMAL="$(echo "$VOD_DE $LAST_LINE_NO" | awk '{printf "%.2f", $1 / $2}')"

h=$(( VOD_TIME / 3600 ))
m=$(( ( VOD_TIME / 60 ) % 60 ))
s=$(( VOD_TIME % 60 ))

VOD_TIME_EMBED="https://www.twitch.tv/videos/${VOD_ID}?t=$(printf "%02dh%02dm%02ds\n" $h $m $s)"
VOD_PEAK="$(echo $i | awk '{print $2}')"

if [ "$i" = "$LAST_LINE" ]
then
cat << EOF >> cache/$VOD_ID/result_${VOD_ID}.json_old
{
"count": "$P_COUNT",
"p_time": "$VOD_TIME",
"p_rank": "$VOD_PEAK",
"p_rank_nm": "$VOD_DE_NORMAL",
"vod_embed": "$VOD_TIME_EMBED"
}
EOF
else
cat << EOF >> cache/$VOD_ID/result_${VOD_ID}.json_old
{
"count": "$P_COUNT",
"p_time": "$VOD_TIME",
"p_rank": "$VOD_PEAK",
"p_rank_nm": "$VOD_DE_NORMAL",
"vod_embed": "$VOD_TIME_EMBED"
},
EOF
fi
done

cat << EOF >> cache/$VOD_ID/result_${VOD_ID}.json_old
]
}
EOF

jq '.' cache/$VOD_ID/result_${VOD_ID}.json_old > cache/$VOD_ID/result_${VOD_ID}.json
}

function ERROR_JSON(){
cat << EOF > cache/$VOD_ID/result_${VOD_ID}.json_old
{
"result": "error",
"total": "0",
"vod_duration": "0",
"vod_duration_sec": "0",
"data": [
]
}
EOF

jq '.' cache/$VOD_ID/result_${VOD_ID}.json_old > cache/$VOD_ID/result_${VOD_ID}.json
}

### START
mkdir -p cache/$VOD_ID

curl -s -H 'Client-ID: rys2y781u5fm9h7ry792yx7354i1dc' -X GET "https://api.twitch.tv/helix/videos?id="$VOD_ID"" | jq '.' > cache/$VOD_ID/vod_info

BROADCAST_DATE="$(grep '"created_at":' cache/$VOD_ID/vod_info | cut -f4 -d'"')"
BROADCAST_ID="$(grep '"user_id":' cache/$VOD_ID/vod_info | cut -f4 -d'"')"
BROADCAST_DURATION="$(grep '"duration":' cache/$VOD_ID/vod_info | cut -f4 -d'"')"

t="$(echo $BROADCAST_DURATION | tr 'hm' ' ' | sed 's/s//g')"
r="$(echo $t | awk '{print NF}')"

if [ "$r" = 1 ]
then
TIME_S="$(echo $t | awk '{print $1}')"

TIME=${TIME_S}
elif [ "$r" = 2 ]
then
TIME_M="$(expr $(echo $t | awk '{print $1}') \* 60)"
TIME_S="$(echo $t | awk '{print $2}')"

TIME=$(expr ${TIME_M} + ${TIME_S})
elif [ "$r" = 3 ]
then
TIME_H="$(expr $(echo $t | awk '{print $1}') \* 3600)"
TIME_M="$(expr $(echo $t | awk '{print $2}') \* 60)"
TIME_S="$(echo $t | awk '{print $3}')"

TIME=$(expr ${TIME_H} + ${TIME_M} + ${TIME_S})
fi

BROADCAST_DURATION_SEC="$(echo "$TIME" | tr -d ' ')"

RESPONSE "* VOD INFO
BROADCAST_DATE : $BROADCAST_DATE
BROADCAST_ID : $BROADCAST_ID
BROADCAST_DURATION : $BROADCAST_DURATION
BROADCAST_DURATION_SEC : $BROADCAST_DURATION_SEC" l_purple "$BROADCAST_ID"

PAGINATION=
PRE_CLIP=
COUNT_CLIP=1
while true
do
curl -s -H 'Client-ID: rys2y781u5fm9h7ry792yx7354i1dc' -X GET "https://api.twitch.tv/helix/clips?broadcaster_id="$BROADCAST_ID"&first=100&started_at="$BROADCAST_DATE"&after="$PAGINATION"" | jq '.' > cache/$VOD_ID/clips_info
PAGINATION="$(grep '"cursor":' cache/$VOD_ID/clips_info | cut -f4 -d'"')"

PAGINATION_COUNT=0
while [ "$PAGINATION" = "" ]
do
PAGINATION_COUNT=$((PAGINATION_COUNT+1))

curl -s -H 'Client-ID: rys2y781u5fm9h7ry792yx7354i1dc' -X GET "https://api.twitch.tv/helix/clips?broadcaster_id="$BROADCAST_ID"&first=100&started_at="$BROADCAST_DATE"&after="$PAGINATION"" | jq '.' > cache/$VOD_ID/clips_info
PAGINATION="$(grep '"cursor":' cache/$VOD_ID/clips_info | cut -f4 -d'"')"

if [ "$PAGINATION_COUNT" -gt 10 ]
then
ERROR_JSON
exit 0
fi
done

grep '"id":' cache/$VOD_ID/clips_info | cut -f4 -d'"' > cache/$VOD_ID/clips_id
grep '"video_id":' cache/$VOD_ID/clips_info | cut -f4 -d'"' > cache/$VOD_ID/clips_vodid
grep '"view_count":' cache/$VOD_ID/clips_info | tr -d ' a-z:,"_' > cache/$VOD_ID/clips_view

paste -d'|' cache/$VOD_ID/clips_id cache/$VOD_ID/clips_vodid | paste - -d'|' cache/$VOD_ID/clips_view | grep "$VOD_ID" | sed 's/$/\|/g' > cache/$VOD_ID/clips_total

for i in $(cat cache/$VOD_ID/clips_total)
do
CLIP_ID="$(echo $i | cut -f1 -d'|')"
CLIP_VODID="$(echo $i | cut -f2 -d'|')"
CLIP_VIEW="$(echo $i | cut -f3 -d'|')"

if [ "$PRE_CLIP" = "$CLIP_ID" ]
then
RESPONSE "* DONE !" l_purple "$BROADCAST_ID"
awk '!a[$1]++' cache/$VOD_ID/clips_info_total_old > cache/$VOD_ID/clips_info_total
RESPONSE "* Total: $(cat cache/$VOD_ID/clips_info_total | wc -l) !" l_purple "$BROADCAST_ID"
GO
fi

if [ "$COUNT_CLIP" = 1 ]
then
PRE_CLIP="$CLIP_ID"
fi

RESPONSE "[$COUNT_CLIP] $CLIP_ID" l_blue "$BROADCAST_ID"
CLIP_TIME="$(curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Client-ID: rys2y781u5fm9h7ry792yx7354i1dc' -X GET "https://api.twitch.tv/kraken/clips/$CLIP_ID" | jq '.' | grep '"url": "https://www.twitch.tv' | grep -Po '=.*?[^\\]"' | tr -d '="')"

while [ "$CLIP_TIME" = "" ]
do
CLIP_TIME="$(curl -s -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Client-ID: rys2y781u5fm9h7ry792yx7354i1dc' -X GET "https://api.twitch.tv/kraken/clips/$CLIP_ID" | jq '.' | grep '"url": "https://www.twitch.tv' | grep -Po '=.*?[^\\]"' | tr -d '="')"
done

echo "$CLIP_ID $CLIP_TIME $CLIP_VIEW" >> cache/$VOD_ID/clips_info_total_old

COUNT_CLIP=$((COUNT_CLIP+1))
done
done
