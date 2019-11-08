import argparse
import json
import gzip
import typing
import csv
import os.path
import urllib.request


def val(d: dict, *args: str):
    v = d
    for arg in args:
        if v.get(arg) is None:
            return ""
        v = v[arg]
    return v


def process_raw(line: bytes, get_file: typing.Callable):
    raw = json.loads(line)

    def common_raw() -> list:
        out = [
            raw["id"],
            raw["actor"]["id"],
            raw["actor"]["login"],
            raw["repo"]["id"],
            raw["repo"]["name"],
            raw["created_at"]
        ]
        return out

    t = raw["type"]

    def write_raw(out_raw, event=None):
        if event is None:
            event = t

        f = get_file(event)
        for (index, field_val) in enumerate(out_raw):
            has_replaced = False
            if type(field_val) == str:
                for spec in ("\\", "\"", ",", ";", "'", "\t", "\x00", "\r", "\n"):
                    if spec in field_val:
                        field_val = field_val.replace(spec, " ")
                        has_replaced = True

            if type(field_val) == bool:
                field_val = 1 if field_val else 0
                has_replaced = True

            if has_replaced:
                out_raw[index] = field_val

        f.writerow(out_raw)

    out_raw = common_raw()
    payload = raw["payload"]
    if t == "PushEvent":
        out_raw = common_raw()
        out_raw.extend([payload["head"], payload["before"], payload["size"], payload["distinct_size"]])
        write_raw(out_raw)
        for commit in payload["commits"]:
            out_raw = common_raw()
            out_raw.extend([commit["author"]["name"], commit["author"]["email"], commit["sha"]])
            write_raw(out_raw, "push_commit")
    # if t == "CreateEvent":
    #     out_raw.extend([payload["ref_type"], payload["ref"], payload["master_branch"], payload["description"], payload["pusher_type"]])
    #     write_raw(out_raw)
    if t == "WatchEvent":
        # out_raw.extend([payload["action"]])
        write_raw(out_raw)
    if t == "IssueCommentEvent":
        issue = payload["issue"]
        user = issue["user"]
        comment = payload["comment"]
        out_raw.extend([
            payload["action"],
            issue["id"],
            issue["number"],
            issue["html_url"],
            issue["title"],
            issue["state"],
            issue["created_at"],
            user["login"],
            user["id"],
            comment["id"],
            comment["body"]
        ])
        write_raw(out_raw)
    if t == "PullRequestEvent":
        pr = payload["pull_request"]
        base = pr["base"]
        head = pr["head"]

        head_forks = val(head, "repo", "forks")

        def supress_empty_int(v):
            if v == "":
                return 0
            return v

        out_raw.extend([
            pr["number"],
            payload["action"],
            pr["url"],
            pr["title"],
            pr["state"],
            pr["body"],
            pr["merged"],
            pr["comments"],
            pr["commits"],

            val(base, "repo", "full_name"),
            val(head, "repo", "full_name"),

            val(base, "repo", "owner"),
            val(head, "repo", "owner"),

            val(base, "repo", "license", "key"),
            val(head, "repo", "license", "key"),

            supress_empty_int(val(base, "repo", "forks")),
            supress_empty_int(val(head, "repo", "forks")),
        ])
        write_raw(out_raw)

    if t == "IssuesEvent":
        issue = payload["issue"]
        labels = [label["name"].replace(";", ".,") for label in payload["issue"]["labels"]]
        out_raw.extend([
            payload["action"],
            issue["id"],
            issue["number"],
            issue["html_url"],
            issue["title"],
            issue["state"],
            issue["created_at"],
            issue["updated_at"],
            issue["user"]["login"],
            ";".join(labels),
        ])
        write_raw(out_raw)

    if t == "ForkEvent":
        forkee = payload["forkee"]
        out_raw.extend([
            forkee["name"],
            forkee["owner"]["login"],
        ])
        write_raw(out_raw)

outfiles = {}
def get_file(eventtype: str, outfile_prefix:str, gzipout=True)-> typing.IO:
    key = outfile_prefix + "_" + eventtype
    if key not in outfiles:
        outfile_name = outfile_prefix + "_" + eventtype.lower() + ".csv"
        if gzipout:
            outfile_name += ".gz"
            f = gzip.open(outfile_name, "wt", encoding="utf8", newline="")
        else:
            f = open(outfile_name, "wt", encoding="utf8", newline="")
        f_csv = csv.writer(f, quoting=csv.QUOTE_NONNUMERIC)
        outfiles[key] = f_csv
    return outfiles[key]


def process_file(fname: str, gzipout=True, outdir=None, outfile_prefix=None):

    if fname.lower().startswith("http://") or fname.lower().startswith("https://"):
        finput = urllib.request.urlopen(fname)
    else:
        finput = open(fname, mode="rb")

    if fname.lower().endswith(".gz"):
        finput = gzip.GzipFile(fileobj=finput)

    if outfile_prefix is None:
        outfile_prefix = fname

    if outfile_prefix.endswith(".gz"):
        outfile_prefix = outfile_prefix[:-len(".gz")]
    if outfile_prefix.endswith(".json"):
        outfile_prefix = outfile_prefix[:-len(".json")]
    if outdir is not None:
        outfile_prefix = os.path.join(outdir, os.path.basename(outfile_prefix))

    with finput:
        line_number=0
        while True:
            line = finput.readline()
            if not line:
                return
            line_number += 1
            process_raw(line, lambda eventtype: get_file(eventtype, outfile_prefix, gzipout))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", nargs='+', help="input file name")
    parser.add_argument("--outdir", default=None)
    parser.add_argument("--gzip", default=False, action="store_true")
    parser.add_argument("--outfile-prefix", default=None)
    args = parser.parse_args()
    for file in args.file:
        print("Start process:", file)
        process_file(file, gzipout=args.gzip, outdir=args.outdir, outfile_prefix=args.outfile_prefix)


if __name__ == '__main__':
    main()
