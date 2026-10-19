[Srpski (latinica)](README.md) | [English](README.en.md) | [Русский](README.ru.md)

# Apple TV 17.0.3: zakrpa za region `rs` na LG webOS-u

Ovaj alat van mreže proverava originalne datoteke `main.js` i `app.js` pomoću SHA-256 i pravi dve lokalne izmenjene kopije u novom direktorijumu. Ne povezuje se sa televizorom, Apple-om, LG-jem niti mrežom. Repozitorijum ne sadrži potpune Apple JavaScript datoteke, firmver, binarne datoteke, ključeve ili podatke naloga. Izmenjene kopije nastaju samo lokalno, iz vaših originalnih datoteka.

Kompatibilnost je ograničena na tačne ulazne SHA-256 vrednosti u datoteci [patches.json](patches.json), koje odgovaraju Apple TV verziji 17.0.3 na proverenom uređaju. Pri bilo kom nepoklapanju program prekida rad. Generator ne menja firmver, izvršnu datoteku, potpis, DRM, aplikaciju na televizoru, podešavanja prodavnice niti automatska ažuriranja Store-a. Ažuriranje Apple TV aplikacije može da zameni zakrpu ili je učini nekompatibilnom; posle bilo kog ažuriranja ove datoteke ne treba ponovo koristiti bez nove provere. Trajna izmena obe datoteke proverena je posle običnog ponovnog pokretanja jednog uređaja; pokretanje posle potpunog isključivanja napajanja nije zasebno provereno. Detalji su u [VALIDATION-RU.md](VALIDATION-RU.md), na ruskom. Sam generator ne proverava ponašanje aplikacije tokom rada.

Zakrpa prilagođava regionalne parametre servisa za region `rs` i onemogućava put automatskog ažuriranja JSUpdater-a za ovu tačno određenu verziju. Automatska ažuriranja Store-a ostaju uključena. Ovo nije obećanje trajne kompatibilnosti, uspešnog prijavljivanja ili reprodukcije DRM-zaštićenog videa.

## Preduslov: root pristup televizoru

Pre primene izmena na televizoru morate već imati potvrđen root pristup. Lokalnom oflajn generatoru na računaru root nije potreban; upis u aplikaciju i prelazak na trajni overlay na televizoru ga zahtevaju.

Na proverenom uređaju korišćen je [SlopBro autora throwaway96](https://github.com/throwaway96/slopbro), u [istorijski zabeleženoj reviziji `21023d56ca424607bb03d2939609cc658c655fc7`](https://github.com/throwaway96/slopbro/tree/21023d56ca424607bb03d2939609cc658c655fc7), koji instalira [webOS Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel). SlopBro je korišćena root alatka; Homebrew Channel je povezani alat instaliran tim postupkom.

Pre izbora root metode proverite u aktuelnoj dokumentaciji autora da li su podržani vaš tačan model, regionalni sufiks i verzija firmvera. Ovo nije univerzalna metoda za sve LG televizore. Podudaranje Apple TV JS heševa ne potvrđuje kompatibilnost root metode sa firmverom.

Root i trajne izmene nose rizik gubitka podataka ili neispravnog rada uređaja. Vraćanje fabričkog firmvera preko USB-a nije garantovano i ne sme se smatrati sigurnim planom oporavka. Skripte ove zakrpe ne obavljaju root postupak i ne preuzimaju niti pokreću SlopBro ili instalaciju Homebrew Channel-a; priprema root pristupa je zaseban korak.

## Upotreba

Potrebni su Python 3.9+ i direktorijum sa originalnim datotekama `main.js` i `app.js`, zakonito preuzetim sa sopstvenog televizora ili iz rezervne kopije.

```sh
python3 apply_patch.py --input-dir /path/to/your/original-js --output-dir /path/to/new/local-candidates
```

Izlazni direktorijum ne sme već da postoji. Program prvo proverava obe ulazne datoteke i priprema oba rezultata u memoriji. Tek kada proveri obe očekivane izlazne SHA-256 vrednosti, pravi novi direktorijum i u njega upisuje `main.js`, `app.js` i `SHA256SUMS.json`. Ne prepisuje postojeći izlazni direktorijum. Generisane datoteke čuvajte lokalno i ne dodajte ih u Git.

Datoteka `patches.json` čuva samo početne i ciljne SHA-256 vrednosti, pomeraje, dužine uklonjenih delova, SHA-256 uklonjenih bajtova i Base64 novih bajtova. Ne sadrži izvorne tekstualne sidrene nizove proizvođača, potpune Apple datoteke niti okolni izvorni kontekst. Primena uvek zahteva originale sa potpuno odgovarajućim SHA-256 vrednostima.

## Provera

Sledeća komanda koristi samo sintetičke testne podatke:

```sh
python3 -m unittest discover -s tests
```

Ni testovi ni generator ne menjaju televizor. Provera stvarnih originala potvrđuje samo da rezultat bajt po bajt odgovara prethodno pripremljenoj izmenjenoj kopiji; ne dokazuje ponašanje aplikacije tokom rada, prijavljivanje ili reprodukciju.

## Licenca i poreklo

Polazna ideja i regionalno prilagođavanje povezani su sa projektom [mircea1223/lg-appletv-romania](https://github.com/mircea1223/lg-appletv-romania/tree/a0fdd116310305d2d85f14bcdbd321d31b13bd28). Njegov alat navodi SPDX `AGPL-3.0-or-later`; ovde su zadržani navođenje izvora i taj SPDX identifikator za generator i metapodatke zakrpe. Python kod izvornog projekta i njegovi sidreni nizovi iz minimizovanog Apple koda nisu kopirani u ovaj paket. Pun tekst GNU AGPL verzije 3 nalazi se u datotekama [LICENSE](LICENSE) i [COPYING](COPYING). Primenjuje se SPDX `AGPL-3.0-or-later`; poreklo izmena opisano je u [PROVENANCE.md](PROVENANCE.md), na engleskom.

Zaštitni postupak prelaska sa prethodne lokalne instalacije zasnovane na bind-mount podmenama nalazi se u direktorijumu [tv-migration/](tv-migration/). Njegovi preduslovi, ograničenja i uslovi vraćanja originalnih datoteka opisani su posebno u [tv-migration/README-RU.md](tv-migration/README-RU.md), na ruskom. Paket ne sadrži univerzalni instalacioni alat niti kompletan firmver.

Ponovna reprodukcija posle poslednje trajne instalacije i ponovnog pokretanja još čeka proveru vlasnika. Potvrđeni su očuvani JS fajlovi, standardno pokretanje Apple TV aplikacije i očuvano stanje Home v6.
