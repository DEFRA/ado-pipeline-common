$version = "1.1.6"
$exists = git tag -l "$version"
if ($exists) { 
    echo "Tag already exists"
}
else {
    git tag $version
    git push origin $version
}
