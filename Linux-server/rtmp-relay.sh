#!/bin/bash

# wrzucic do /usr/local/bin/
# aby uruchamial sie na starcie systemu

# Skrypt do przekazywania RTMP do HLS
# Automatycznie tworzy strumień HLS z RTMP

# Konfiguracja
RTMP_SOURCE="rtmp://192.168.1.200:1935/live/stream"
HLS_OUTPUT_DIR="/var/www/html/hls"
STREAM_NAME="stream"

# Kolory dla lepszej czytelności
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funkcja pomocy
show_help() {
    echo -e "${BLUE}📡 RTMP to HLS Relay Script${NC}"
    echo "================================"
    echo "Użycie: $0 [OPCJE] <rtmp_url> [stream_name]"
    echo ""
    echo "Opcje:"
    echo "  -h, --help     Pokaż tę pomoc"
    echo "  -q, --quality  Ustaw jakość (low|medium|high)"
    echo "  -d, --debug    Włącz tryb debug"
    echo ""
    echo "Przykłady:"
    echo "  $0 rtmp://192.168.1.200:1935/live/stream"
    echo "  $0 rtmp://192.168.1.200:1935/live/stream mojstream"
    echo "  $0 -q high rtmp://192.168.1.200:1935/live/stream"
    echo ""
    echo "Wynikowy HLS będzie dostępny pod:"
    echo "  http://localhost/hls/[stream_name]/playlist.m3u8"
}

# Parsowanie argumentów
QUALITY="medium"
DEBUG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        )
            if [ -z "$RTMP_SOURCE" ] || [[ "$1" == rtmp:// ]]; then
                RTMP_SOURCE="$1"
                shift
            elif [ -z "$STREAM_NAME" ] || [[ "$1" != -* ]]; then
                STREAM_NAME="$1"
                shift
            else
                echo -e "${RED}❌ Nieznany argument: $1${NC}"
                show_help
                exit 1
            fi
            ;;
    esac
done

# Sprawdź argumenty
if [ -z "$RTMP_SOURCE" ]; then
    echo -e "${RED}❌ Nie podano źródła RTMP${NC}"
    show_help
    exit 1
fi

# Ustawienia jakości
case $QUALITY in
    low)
        VIDEO_BITRATE="500k"
        AUDIO_BITRATE="64k"
        RESOLUTION="854x480"
        ;;
    medium)
        VIDEO_BITRATE="1000k"
        AUDIO_BITRATE="128k"
        RESOLUTION="1280x720"
        ;;
    high)
        VIDEO_BITRATE="2000k"
        AUDIO_BITRATE="192k"
        RESOLUTION="1920x1080"
        ;;
    *)
        echo -e "${YELLOW}⚠️  Nieznana jakość '$QUALITY', używam 'medium'${NC}"
        QUALITY="medium"
        VIDEO_BITRATE="1000k"
        AUDIO_BITRATE="128k"
        RESOLUTION="1280x720"
        ;;
esac

# Utwórz katalog dla strumienia
OUTPUT_DIR="$HLS_OUTPUT_DIR/$STREAM_NAME"
echo -e "${BLUE}📁 Tworzenie katalogu: $OUTPUT_DIR${NC}"
sudo mkdir -p "$OUTPUT_DIR"
sudo chown -R www-data:www-data "$HLS_OUTPUT_DIR"

# Sprawdź dostępność FFmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}❌ FFmpeg nie jest zainstalowany${NC}"
    echo -e "${YELLOW}💡 Zainstaluj: sudo apt install ffmpeg${NC}"
    exit 1
fi

# Sprawdź połączenie ze źródłem RTMP
echo -e "${BLUE}🔍 Sprawdzanie źródła RTMP...${NC}"
timeout 5 ffprobe "$RTMP_SOURCE" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Nie można sprawdzić źródła RTMP (może być niedostępne)${NC}"
    echo -e "${BLUE}🚀 Próbuję mimo to...${NC}"
fi

# Wyświetl informacje
echo -e "${GREEN}✅ Konfiguracja:${NC}"
echo -e "   📡 Źródło RTMP: $RTMP_SOURCE"
echo -e "   🎬 Nazwa strumienia: $STREAM_NAME"
echo -e "   📁 Katalog wyjściowy: $OUTPUT_DIR"
echo -e "   🎥 Jakość: $QUALITY ($RESOLUTION, $VIDEO_BITRATE)"
echo -e "   🌐 URL HLS: http://localhost/hls/$STREAM_NAME/playlist.m3u8"
echo -e "${YELLOW}⏹️  Naciśnij Ctrl+C aby zatrzymać${NC}"
echo ""

# Ustawienia FFmpeg
FFMPEG_ARGS=(
    -i "$RTMP_SOURCE"
    -c:v libx264
    -preset veryfast
    -tune zerolatency
    -c:a aac
    -b:v "$VIDEO_BITRATE"
    -b:a "$AUDIO_BITRATE"
    -vf "scale=$RESOLUTION"
    -g 30
    -sc_threshold 0
    -f hls
    -hls_time 2
    -hls_list_size 10
    -hls_flags delete_segments+append_list
    -hls_allow_cache 0
    -hls_segment_filename "$OUTPUT_DIR/segment%03d.ts"
    "$OUTPUT_DIR/playlist.m3u8"
)

# Dodaj debug jeśli włączony
if [ "$DEBUG" = true ]; then
    FFMPEG_ARGS=(-loglevel debug "${FFMPEG_ARGS[@]}")
    echo -e "${BLUE}🐛 Tryb debug włączony${NC}"
fi

# Funkcja sprzątania
cleanup() {
    echo -e "\n${YELLOW}🧹 Sprzątanie...${NC}"
    sudo rm -f "$OUTPUT_DIR"/.ts "$OUTPUT_DIR"/.m3u8
    echo -e "${GREEN}✅ Zakończono${NC}"
    exit 0
}

# Przechwytuj Ctrl+C
trap cleanup SIGINT SIGTERM

# Uruchom FFmpeg
echo -e "${GREEN}🚀 Uruchamianie przekazywania RTMP → HLS...${NC}"
ffmpeg "${FFMPEG_ARGS[@]}"

# Jeśli FFmpeg zakończy się błędem
echo -e "${RED}❌ FFmpeg zakończył się błędem${NC}"
cleanup