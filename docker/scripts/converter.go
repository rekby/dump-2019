package main

import (
    "bufio"
    "compress/gzip"
    "encoding/csv"
    "encoding/json"
    "errors"
    "flag"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "path/filepath"
    "runtime"
    "strconv"
    "strings"
    "sync"
    "time"
)

// parser.add_argument("file", nargs='+', help="input file name")
// parser.add_argument("--outdir", default=None)
// parser.add_argument("--gzip", default=False, action="store_true")
// parser.add_argument("--outfile-prefix", default=None)
// args = parser.parse_args()

var (
    pOutDir = flag.String("outdir", "", "")
    pGzipOut = flag.Bool("gzip", true, "")
    pYear = flag.Int("year", 0, "")
    pSource = flag.String("source", "https://data.gharchive.org", "")
    pMonth = flag.Int("month", 0, "")
    pDay = flag.Int("day", 0, "")
)

type Event struct {
    ID string
    Type string
    Actor struct {
        ID int
        Login string
    }
    Repo struct {
        ID int
        Name string
    }
    CreatedAt string `json:"created_at"`
    Payload json.RawMessage
}
func (e *Event) Fields()[]string{
    return []string {
        e.ID,
        strconv.Itoa(e.Actor.ID),
        e.Actor.Login,
        strconv.Itoa(e.Repo.ID),
        e.Repo.Name,
        e.CreatedAt,
    }
}

type PushEventPayload struct {
    Head string
    Before string
    Size int
    DistinctSize int `json:"distinct_size"`
}

func openFile(fname string)(io.ReadCloser, error){
    l := strings.ToLower(fname)
    var reader io.ReadCloser
    var err error
    if strings.HasPrefix(l, "http://") || strings.HasPrefix(l, "https://") {
        resp, err := http.Get(fname)
        if err != nil {
            return nil, err
        }
        if resp.StatusCode != http.StatusOK {
            return nil, errors.New("Bad return code: " + resp.Status)
        }
        reader = resp.Body
    } else {
        reader, err = os.Open(fname)
        if err != nil {
            return nil, err
        }
    }
    
    if strings.HasSuffix(l, ".gz") {
        reader, err = gzip.NewReader(reader)
        if err != nil {
            return nil, err
        }
    }
    
    return reader, nil
}

func writeFields(c *csv.Writer, fields []string)error{
    for fieldIndex, field := range fields{
        for _, sub := range []string{"\\", "\"", ",", ";", "'", "\t", "\x00", "\r", "\n"}{
            field = strings.Replace(field, sub, " ", -1)
        }
        fields[fieldIndex] = field
    }
    return c.Write(fields)
}

func processLine(line []byte, files *OutFiles)error{
    var event Event
    err := json.Unmarshal(line, &event)
    if err != nil {
        return err
    }
    
    switch event.Type {
    case "PushEvent":
        var payload PushEventPayload
        err := json.Unmarshal([]byte(event.Payload), &payload)
        if err != nil {
            return err
        }
        fields := append(event.Fields(), []string{
            payload.Head, payload.Before, strconv.Itoa(payload.Size), strconv.Itoa(payload.DistinctSize),
        }...)
        return writeFields(files.GetWriter(event.Type), fields)
    }
    return nil
}

func processReader(r io.ReadCloser, files *OutFiles) error {
    scanner := bufio.NewScanner(r)
    lineNumber := 0
    for scanner.Scan(){
        lineNumber++
        err := processLine(scanner.Bytes(), files)
        if err != nil {
            return fmt.Errorf("can't process line line '%v': %v", lineNumber, err)
        }
    }
    return nil
}

func dateExist(year, month, day int)bool{
    t := time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.UTC)
    return t.Day() == day && int(t.Month()) == month && t.Year() == year
}

type Stream struct {
    Name string
    InFiles []string
    OutFiles *OutFiles
}

func(s *Stream)String()string{
    return s.Name
}

type OutFiles struct {
    prefix string
    csv map[string]*csv.Writer
    writers []io.Closer
    tmpFiles []string
}

func(o *OutFiles) GetWriter(t string)*csv.Writer{
    if _, ok := o.csv[t]; !ok {
        outFileName := o.prefix + "_" + strings.ToLower(t) + ".csv"
        if *pGzipOut {
            outFileName += ".gz"
        }
        outFileName += ".tmp"
        f, err := os.Create(outFileName)
        if err != nil {
            log.Fatalf("Can't create outfile '%v': %v", outFileName, err)
        }
        o.tmpFiles = append(o.tmpFiles, outFileName)
        o.writers = append(o.writers, f)
        var writer io.WriteCloser = f
        if *pGzipOut {
            writer = gzip.NewWriter(writer)
            o.writers = append(o.writers, writer)
        }
        csvWriter := csv.NewWriter(writer)
        csvWriter.UseCRLF = true
        o.csv[t] = csvWriter
    }
    return o.csv[t]
}

func (o *OutFiles)Close(ok bool){
    for key, c :=range o.csv{
        c.Flush()
        err := c.Error()
        if err != nil {
            log.Println("Error flush csv '%v': %v",key, err)
        }
    }
    
    for i := len(o.writers)-1; i >= 0; i--{
        err := o.writers[i].Close()
        if err != nil {
            log.Println("Error out close: %v", err)
        }
    }
    
    if ok {
        for _, tmpfName := range o.tmpFiles {
            fName := strings.TrimSuffix(tmpfName, ".tmp")
            err := os.Rename(tmpfName, fName)
            if err != nil {
                log.Println("Error rename '%v' -> '%v': %v", tmpfName, fName, err)
            }
        }
    }
}

func isHttp(s string )bool{
    return strings.HasPrefix(s, "http://") || strings.HasPrefix(s, "https://")
}

func streamGenerator() []*Stream {
    
    var res []*Stream
    var minMonth, maxMonth= 1, 12

    minYear, maxYear := 2015, time.Now().Year()
    if *pYear != 0 {
        minYear, maxYear = *pYear, *pYear
    }
    
    if *pMonth != 0 {
        minMonth, maxMonth = *pMonth, *pMonth
    }
    
    var minDay, maxDay= 1, 31
    if *pDay != 0 {
        minDay, maxDay = *pDay, *pDay
    }
    for year := minYear; year <=maxYear; year++ {
        for month := minMonth; month <= maxMonth; month++ {
            for day := minDay; day <= maxDay; day++ {
                if !dateExist(year, month, day) {
                    break
                }
                
                outFilePrefix := fmt.Sprintf("%4d-%02d-%02d", year, month, day)
                
                outFiles := OutFiles{
                    prefix:  filepath.Join(*pOutDir, outFilePrefix),
                    csv:     make(map[string]*csv.Writer),
                    writers: nil,
                }
                var stream = &Stream{
                    Name:     outFilePrefix,
                    OutFiles: &outFiles,
                    InFiles:  make([]string, 0, 24),
                }
                for hour := 0; hour <= 23; hour++ {
                    fName := fmt.Sprintf("%4d-%02d-%02d-%d.json.gz", year, month, day, hour)
                    if isHttp(*pSource) {
                        fName = *pSource + "/" + fName
                    } else {
                        fName = filepath.Join(*pSource, fName)
                    }
                    filePath := fName
                    stream.InFiles = append(stream.InFiles, filePath)
                }
                res = append(res, stream)
            }
        }
    }
    return res
}

func processStream(stream *Stream) {
    processOk := false
    log.Printf("Start stream: %v\n", stream.Name)
    defer func() {
        stream.OutFiles.Close(processOk)
    }()
    
    for _, inFileName := range stream.InFiles{
        inFile, err := openFile(inFileName)
        if err != nil {
            log.Printf("Can't open read file '%v': %v\n", inFile, err)
            return
        }
        err = processReader(inFile, stream.OutFiles)
        if err != nil {
            log.Printf("Error process file '%v' %v\n", inFileName, err)
            return
        }
    }
    processOk = true
    log.Printf("Finish: %v\n", stream.Name)
}

func work(streams []*Stream){
    workerCount := runtime.NumCPU()
    
    var wg sync.WaitGroup
    wg.Add(workerCount)
    
    tasks := make(chan *Stream)
    go func() {
        for _, stream := range streams{
            tasks <- stream
        }
        close(tasks)
    }()
    
    for i := 0; i < workerCount; i++ {
        go func() {
            defer wg.Done()
            
            for stream := range tasks {
                processStream(stream)
            }
        }()
    }
    wg.Wait()
}

func main(){
    flag.Parse()
    
    streams := streamGenerator()
    
    work(streams)
}
